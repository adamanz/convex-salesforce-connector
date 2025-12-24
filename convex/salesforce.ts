import { v } from "convex/values";
import { internalMutation, internalAction, query, action } from "./_generated/server";
import { internal } from "./_generated/api";
import { getEnabledObjects, getObjectByApiName, buildFieldList, mapRecordToDocument } from "./config";

// ============================================================================
// GENERIC CDC PROCESSOR
// Handles any Salesforce object based on config
// ============================================================================

const nullToUndefined = <T>(val: T | null): T | undefined => (val === null ? undefined : val);

/**
 * Generic upsert for any Salesforce object
 */
export const upsertRecord = internalMutation({
  args: {
    tableName: v.string(),
    sfId: v.string(),
    changeType: v.string(),
    replayId: v.optional(v.string()),
    data: v.any(),
  },
  handler: async (ctx, args) => {
    const { tableName, sfId, changeType, replayId, data } = args;
    const now = Date.now();
    const isDelete = changeType === "DELETE";

    // Get object config
    const objConfig = getEnabledObjects().find((o) => o.tableName === tableName);
    if (!objConfig) {
      throw new Error(`Unknown table: ${tableName}`);
    }

    // Map fields from Salesforce to Convex
    const mappedData = mapRecordToDocument(objConfig, data);

    // Build the record with CDC metadata
    const record = {
      sfId,
      ...mappedData,
      cdcChangeType: changeType,
      cdcReplayId: replayId,
      isDeleted: isDelete,
      syncedAt: now,
      sfCreatedDate: nullToUndefined(data.CreatedDate),
      sfLastModifiedDate: nullToUndefined(data.LastModifiedDate),
    };

    // Check for existing record
    const existing = await ctx.db
      .query(tableName as any)
      .withIndex("by_sfId", (q: any) => q.eq("sfId", sfId))
      .first();

    if (existing) {
      await ctx.db.patch(existing._id, record);
      return { action: "updated", id: existing._id };
    } else {
      const id = await ctx.db.insert(tableName as any, record);
      return { action: "created", id };
    }
  },
});

/**
 * Process a single CDC event
 */
export const processCdcEvent = internalAction({
  args: {
    objectType: v.string(),
    changeType: v.string(),
    recordId: v.string(),
    replayId: v.optional(v.string()),
    changedFields: v.optional(v.array(v.string())),
    data: v.any(),
  },
  returns: v.object({
    success: v.boolean(),
    action: v.optional(v.string()),
    id: v.optional(v.any()),
    error: v.optional(v.string()),
  }),
  handler: async (ctx, args): Promise<{ success: boolean; action?: string; id?: any; error?: string }> => {
    const { objectType, changeType, recordId, replayId, data } = args;

    console.log(`Processing CDC event: ${objectType} ${changeType} ${recordId}`);

    // Get object config
    const objConfig = getObjectByApiName(objectType);
    if (!objConfig || !objConfig.enabled) {
      console.warn(`Object type not configured or disabled: ${objectType}`);
      return { success: false, error: `Object type not configured: ${objectType}` };
    }

    try {
      const result = await ctx.runMutation(internal.salesforce.upsertRecord, {
        tableName: objConfig.tableName,
        sfId: recordId,
        changeType,
        replayId,
        data,
      });

      // Log the event
      await ctx.runMutation(internal.salesforce.logCdcEvent, {
        objectType,
        changeType,
        recordId,
        replayId,
        success: true,
      });

      return { success: true, ...result };
    } catch (error: any) {
      console.error(`CDC processing error:`, error);

      await ctx.runMutation(internal.salesforce.logCdcEvent, {
        objectType,
        changeType,
        recordId,
        replayId,
        success: false,
        error: error.message,
      });

      return { success: false, error: error.message };
    }
  },
});

/**
 * Process batch of CDC events
 */
export const processCdcBatch = internalAction({
  args: {
    events: v.array(
      v.object({
        objectType: v.string(),
        changeType: v.string(),
        recordId: v.string(),
        replayId: v.optional(v.string()),
        changedFields: v.optional(v.array(v.string())),
        data: v.any(),
      })
    ),
  },
  returns: v.object({
    processed: v.number(),
    succeeded: v.number(),
    failed: v.number(),
  }),
  handler: async (ctx, args): Promise<{ processed: number; succeeded: number; failed: number }> => {
    let succeeded = 0;
    let failed = 0;

    for (const event of args.events) {
      const objConfig = getObjectByApiName(event.objectType);
      if (!objConfig || !objConfig.enabled) {
        failed++;
        continue;
      }

      try {
        await ctx.runMutation(internal.salesforce.upsertRecord, {
          tableName: objConfig.tableName,
          sfId: event.recordId,
          changeType: event.changeType,
          replayId: event.replayId,
          data: event.data,
        });
        succeeded++;
      } catch (error: any) {
        console.error(`Batch CDC error for ${event.recordId}:`, error.message);
        failed++;
      }
    }

    return { processed: args.events.length, succeeded, failed };
  },
});

/**
 * Log CDC event for debugging
 */
export const logCdcEvent = internalMutation({
  args: {
    objectType: v.string(),
    changeType: v.string(),
    recordId: v.string(),
    replayId: v.optional(v.string()),
    success: v.boolean(),
    error: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    await ctx.db.insert("cdcEventLog", {
      ...args,
      processedAt: Date.now(),
    });
  },
});

// ============================================================================
// BULK SYNC
// ============================================================================

/**
 * Bulk sync records from Salesforce for a specific object
 */
export const bulkSync = action({
  args: {
    objectType: v.string(),
    limit: v.optional(v.number()),
  },
  returns: v.object({
    success: v.boolean(),
    synced: v.number(),
    error: v.optional(v.string()),
  }),
  handler: async (ctx, args): Promise<{ success: boolean; synced: number; error?: string }> => {
    const { objectType, limit } = args;

    const objConfig = getObjectByApiName(objectType);
    if (!objConfig || !objConfig.enabled) {
      return { success: false, synced: 0, error: `Object not configured: ${objectType}` };
    }

    const instanceUrl = process.env.SALESFORCE_INSTANCE_URL;
    const accessToken = process.env.SALESFORCE_ACCESS_TOKEN;

    if (!instanceUrl || !accessToken) {
      return { success: false, synced: 0, error: "Missing Salesforce credentials" };
    }

    const fields = buildFieldList(objConfig);
    let query = `SELECT ${fields} FROM ${objectType}`;
    if (limit) query += ` LIMIT ${limit}`;

    try {
      const response = await fetch(
        `${instanceUrl}/services/data/v59.0/query?q=${encodeURIComponent(query)}`,
        {
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
        }
      );

      if (!response.ok) {
        const error = await response.text();
        return { success: false, synced: 0, error: `Query failed: ${error}` };
      }

      const data = await response.json();
      const records = data.records || [];
      let synced = 0;

      for (const record of records) {
        try {
          await ctx.runMutation(internal.salesforce.upsertRecord, {
            tableName: objConfig.tableName,
            sfId: record.Id,
            changeType: "SYNC",
            data: record,
          });
          synced++;
        } catch (error: any) {
          console.error(`Sync error for ${record.Id}:`, error.message);
        }
      }

      return { success: true, synced };
    } catch (error: any) {
      return { success: false, synced: 0, error: error.message };
    }
  },
});

/**
 * Sync all enabled objects
 */
export const syncAll = action({
  args: {
    limit: v.optional(v.number()),
  },
  returns: v.object({
    success: v.boolean(),
    results: v.any(),
  }),
  handler: async (ctx, args): Promise<{ success: boolean; results: any }> => {
    const results: Record<string, any> = {};

    for (const obj of getEnabledObjects()) {
      console.log(`Syncing ${obj.label}...`);
      const result = await ctx.runAction(internal.salesforce.bulkSync, {
        objectType: obj.apiName,
        limit: args.limit,
      });
      results[obj.apiName] = result;
    }

    return { success: true, results };
  },
});

// ============================================================================
// SALESFORCE API OPERATIONS
// ============================================================================

/**
 * Update a Salesforce record
 */
export const updateRecord = action({
  args: {
    objectType: v.string(),
    recordId: v.string(),
    fields: v.any(),
  },
  returns: v.object({
    success: v.boolean(),
    error: v.optional(v.string()),
  }),
  handler: async (ctx, args): Promise<{ success: boolean; error?: string }> => {
    const instanceUrl = process.env.SALESFORCE_INSTANCE_URL;
    const accessToken = process.env.SALESFORCE_ACCESS_TOKEN;

    if (!instanceUrl || !accessToken) {
      return { success: false, error: "Missing Salesforce credentials" };
    }

    try {
      const response = await fetch(
        `${instanceUrl}/services/data/v59.0/sobjects/${args.objectType}/${args.recordId}`,
        {
          method: "PATCH",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify(args.fields),
        }
      );

      if (response.status === 204) {
        return { success: true };
      }

      if (!response.ok) {
        const error = await response.json();
        return { success: false, error: error[0]?.message || `Failed: ${response.status}` };
      }

      return { success: true };
    } catch (error: any) {
      return { success: false, error: error.message };
    }
  },
});

/**
 * Query Salesforce using SOQL
 */
export const query = action({
  args: {
    soql: v.string(),
  },
  returns: v.object({
    success: v.boolean(),
    records: v.optional(v.array(v.any())),
    totalSize: v.optional(v.number()),
    error: v.optional(v.string()),
  }),
  handler: async (ctx, args) => {
    const instanceUrl = process.env.SALESFORCE_INSTANCE_URL;
    const accessToken = process.env.SALESFORCE_ACCESS_TOKEN;

    if (!instanceUrl || !accessToken) {
      return { success: false, error: "Missing Salesforce credentials" };
    }

    try {
      const response = await fetch(
        `${instanceUrl}/services/data/v59.0/query?q=${encodeURIComponent(args.soql)}`,
        {
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
        }
      );

      if (!response.ok) {
        const error = await response.json();
        return { success: false, error: error[0]?.message || `Query failed: ${response.status}` };
      }

      const data = await response.json();
      return { success: true, records: data.records, totalSize: data.totalSize };
    } catch (error: any) {
      return { success: false, error: error.message };
    }
  },
});

// ============================================================================
// STATUS QUERIES
// ============================================================================

/**
 * Get sync statistics
 */
export const getSyncStats = query({
  args: {},
  handler: async (ctx) => {
    const stats: Record<string, { total: number; active: number; deleted: number }> = {};

    for (const obj of getEnabledObjects()) {
      const records = await ctx.db.query(obj.tableName as any).collect();
      stats[obj.apiName] = {
        total: records.length,
        active: records.filter((r: any) => !r.isDeleted).length,
        deleted: records.filter((r: any) => r.isDeleted).length,
      };
    }

    return stats;
  },
});

/**
 * Get enabled object configuration
 */
export const getConfig = query({
  args: {},
  handler: async () => {
    return getEnabledObjects().map((obj) => ({
      apiName: obj.apiName,
      tableName: obj.tableName,
      label: obj.label,
      fieldCount: obj.fields.length,
    }));
  },
});
