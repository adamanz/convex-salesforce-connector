import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

/**
 * Convex Salesforce Connector Schema
 *
 * This schema defines mirror tables for Salesforce objects synced via CDC.
 * Add or remove tables based on which objects you want to sync.
 */
export default defineSchema({
  // ============================================================================
  // SALESFORCE MIRROR TABLES (CDC Sync)
  // Real-time mirrors of Salesforce objects via Change Data Capture
  // ============================================================================

  // Accounts
  sfAccounts: defineTable({
    sfId: v.string(), // Salesforce Account ID (18-char)
    name: v.string(),
    type: v.optional(v.string()),
    parentId: v.optional(v.string()),

    // Billing Address
    billingStreet: v.optional(v.string()),
    billingCity: v.optional(v.string()),
    billingState: v.optional(v.string()),
    billingPostalCode: v.optional(v.string()),
    billingCountry: v.optional(v.string()),

    // Shipping Address
    shippingStreet: v.optional(v.string()),
    shippingCity: v.optional(v.string()),
    shippingState: v.optional(v.string()),
    shippingPostalCode: v.optional(v.string()),
    shippingCountry: v.optional(v.string()),

    // Contact Info
    phone: v.optional(v.string()),
    website: v.optional(v.string()),

    // Business Info
    industry: v.optional(v.string()),
    annualRevenue: v.optional(v.number()),
    numberOfEmployees: v.optional(v.number()),
    description: v.optional(v.string()),

    // Ownership
    ownerId: v.optional(v.string()),

    // CDC Metadata (automatically populated)
    cdcChangeType: v.optional(v.string()), // CREATE, UPDATE, DELETE, UNDELETE
    cdcReplayId: v.optional(v.string()),
    isDeleted: v.boolean(),
    syncedAt: v.number(),
    sfCreatedDate: v.optional(v.string()),
    sfLastModifiedDate: v.optional(v.string()),
  })
    .index("by_sfId", ["sfId"])
    .index("by_name", ["name"])
    .index("by_owner", ["ownerId"])
    .index("by_deleted", ["isDeleted"]),

  // Contacts
  sfContacts: defineTable({
    sfId: v.string(),
    accountId: v.optional(v.string()),

    // Name
    firstName: v.optional(v.string()),
    lastName: v.string(),
    name: v.string(),
    salutation: v.optional(v.string()),
    title: v.optional(v.string()),

    // Mailing Address
    mailingStreet: v.optional(v.string()),
    mailingCity: v.optional(v.string()),
    mailingState: v.optional(v.string()),
    mailingPostalCode: v.optional(v.string()),
    mailingCountry: v.optional(v.string()),

    // Other Address
    otherStreet: v.optional(v.string()),
    otherCity: v.optional(v.string()),
    otherState: v.optional(v.string()),
    otherPostalCode: v.optional(v.string()),
    otherCountry: v.optional(v.string()),

    // Contact Info
    phone: v.optional(v.string()),
    mobilePhone: v.optional(v.string()),
    homePhone: v.optional(v.string()),
    email: v.optional(v.string()),

    // Ownership
    ownerId: v.optional(v.string()),
    reportsToId: v.optional(v.string()),

    // CDC Metadata
    cdcChangeType: v.optional(v.string()),
    cdcReplayId: v.optional(v.string()),
    isDeleted: v.boolean(),
    syncedAt: v.number(),
    sfCreatedDate: v.optional(v.string()),
    sfLastModifiedDate: v.optional(v.string()),
  })
    .index("by_sfId", ["sfId"])
    .index("by_accountId", ["accountId"])
    .index("by_email", ["email"])
    .index("by_phone", ["phone"])
    .index("by_mobilePhone", ["mobilePhone"])
    .index("by_owner", ["ownerId"])
    .index("by_deleted", ["isDeleted"]),

  // Leads
  sfLeads: defineTable({
    sfId: v.string(),

    // Name
    firstName: v.optional(v.string()),
    lastName: v.string(),
    name: v.string(),
    salutation: v.optional(v.string()),
    title: v.optional(v.string()),
    company: v.optional(v.string()),

    // Address
    street: v.optional(v.string()),
    city: v.optional(v.string()),
    state: v.optional(v.string()),
    postalCode: v.optional(v.string()),
    country: v.optional(v.string()),

    // Contact Info
    phone: v.optional(v.string()),
    email: v.optional(v.string()),
    website: v.optional(v.string()),

    // Lead Info
    status: v.optional(v.string()),
    leadSource: v.optional(v.string()),
    industry: v.optional(v.string()),
    rating: v.optional(v.string()),
    annualRevenue: v.optional(v.number()),
    numberOfEmployees: v.optional(v.number()),
    description: v.optional(v.string()),

    // Conversion
    isConverted: v.optional(v.boolean()),
    convertedAccountId: v.optional(v.string()),
    convertedContactId: v.optional(v.string()),
    convertedOpportunityId: v.optional(v.string()),
    convertedDate: v.optional(v.string()),

    // Ownership
    ownerId: v.optional(v.string()),

    // CDC Metadata
    cdcChangeType: v.optional(v.string()),
    cdcReplayId: v.optional(v.string()),
    isDeleted: v.boolean(),
    syncedAt: v.number(),
    sfCreatedDate: v.optional(v.string()),
    sfLastModifiedDate: v.optional(v.string()),
  })
    .index("by_sfId", ["sfId"])
    .index("by_email", ["email"])
    .index("by_phone", ["phone"])
    .index("by_status", ["status"])
    .index("by_owner", ["ownerId"])
    .index("by_deleted", ["isDeleted"]),

  // Opportunities
  sfOpportunities: defineTable({
    sfId: v.string(),
    accountId: v.optional(v.string()),

    // Basic Info
    name: v.string(),
    description: v.optional(v.string()),

    // Stage & Amount
    stageName: v.string(),
    amount: v.optional(v.number()),
    probability: v.optional(v.number()),
    closeDate: v.optional(v.string()),

    // Classification
    type: v.optional(v.string()),
    leadSource: v.optional(v.string()),
    nextStep: v.optional(v.string()),
    forecastCategoryName: v.optional(v.string()),

    // Status flags
    isClosed: v.optional(v.boolean()),
    isWon: v.optional(v.boolean()),

    // Ownership
    ownerId: v.optional(v.string()),

    // CDC Metadata
    cdcChangeType: v.optional(v.string()),
    cdcReplayId: v.optional(v.string()),
    isDeleted: v.boolean(),
    syncedAt: v.number(),
    sfCreatedDate: v.optional(v.string()),
    sfLastModifiedDate: v.optional(v.string()),
  })
    .index("by_sfId", ["sfId"])
    .index("by_accountId", ["accountId"])
    .index("by_stageName", ["stageName"])
    .index("by_closeDate", ["closeDate"])
    .index("by_owner", ["ownerId"])
    .index("by_deleted", ["isDeleted"]),

  // Tasks
  sfTasks: defineTable({
    sfId: v.string(),

    // Related Records
    whoId: v.optional(v.string()),
    whatId: v.optional(v.string()),

    // Task Info
    subject: v.optional(v.string()),
    description: v.optional(v.string()),
    status: v.optional(v.string()),
    priority: v.optional(v.string()),
    activityDate: v.optional(v.string()),

    // Call Info
    callType: v.optional(v.string()),
    callDurationInSeconds: v.optional(v.number()),
    callDisposition: v.optional(v.string()),

    // Completion
    isCompleted: v.optional(v.boolean()),
    completedDateTime: v.optional(v.string()),

    // Ownership
    ownerId: v.optional(v.string()),

    // CDC Metadata
    cdcChangeType: v.optional(v.string()),
    cdcReplayId: v.optional(v.string()),
    isDeleted: v.boolean(),
    syncedAt: v.number(),
    sfCreatedDate: v.optional(v.string()),
    sfLastModifiedDate: v.optional(v.string()),
  })
    .index("by_sfId", ["sfId"])
    .index("by_whoId", ["whoId"])
    .index("by_whatId", ["whatId"])
    .index("by_status", ["status"])
    .index("by_owner", ["ownerId"])
    .index("by_deleted", ["isDeleted"]),

  // Events
  sfEvents: defineTable({
    sfId: v.string(),

    // Related Records
    whoId: v.optional(v.string()),
    whatId: v.optional(v.string()),

    // Event Info
    subject: v.optional(v.string()),
    description: v.optional(v.string()),
    location: v.optional(v.string()),

    // Timing
    startDateTime: v.optional(v.string()),
    endDateTime: v.optional(v.string()),
    isAllDayEvent: v.optional(v.boolean()),
    durationInMinutes: v.optional(v.number()),

    // Ownership
    ownerId: v.optional(v.string()),

    // CDC Metadata
    cdcChangeType: v.optional(v.string()),
    cdcReplayId: v.optional(v.string()),
    isDeleted: v.boolean(),
    syncedAt: v.number(),
    sfCreatedDate: v.optional(v.string()),
    sfLastModifiedDate: v.optional(v.string()),
  })
    .index("by_sfId", ["sfId"])
    .index("by_whoId", ["whoId"])
    .index("by_whatId", ["whatId"])
    .index("by_startDateTime", ["startDateTime"])
    .index("by_owner", ["ownerId"])
    .index("by_deleted", ["isDeleted"]),

  // ============================================================================
  // CDC EVENT LOG (Optional - for debugging and audit)
  // ============================================================================

  cdcEventLog: defineTable({
    objectType: v.string(),
    changeType: v.string(),
    recordId: v.string(),
    replayId: v.optional(v.string()),
    success: v.boolean(),
    error: v.optional(v.string()),
    processedAt: v.number(),
  })
    .index("by_objectType", ["objectType"])
    .index("by_recordId", ["recordId"])
    .index("by_processedAt", ["processedAt"]),
});
