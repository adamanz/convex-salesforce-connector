import { httpRouter } from "convex/server";
import { httpAction } from "./_generated/server";
import { internal, api } from "./_generated/api";

const http = httpRouter();

// ============================================================================
// SALESFORCE CDC WEBHOOK
// Receives real-time change events from Salesforce
// ============================================================================

/**
 * Receive CDC events from Salesforce
 * Webhook URL: https://<your-deployment>.convex.site/webhooks/salesforce/cdc
 */
http.route({
  path: "/webhooks/salesforce/cdc",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    try {
      const body = await request.json();
      console.log("CDC webhook received:", JSON.stringify(body, null, 2));

      // Support both single event and batch formats
      const events = Array.isArray(body.events) ? body.events : [body];

      if (events.length === 0) {
        return new Response(JSON.stringify({ success: true, processed: 0 }), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        });
      }

      // Process batch
      if (events.length > 1) {
        await ctx.scheduler.runAfter(0, internal.salesforce.processCdcBatch, { events });
        return new Response(
          JSON.stringify({ success: true, queued: events.length }),
          { status: 200, headers: { "Content-Type": "application/json" } }
        );
      }

      // Process single event
      const event = events[0];
      await ctx.scheduler.runAfter(0, internal.salesforce.processCdcEvent, {
        objectType: event.objectType || event.ChangeEventHeader?.entityName,
        changeType: event.changeType || event.ChangeEventHeader?.changeType,
        recordId: event.recordId || event.ChangeEventHeader?.recordIds?.[0],
        replayId: event.replayId || event.ChangeEventHeader?.replayId?.toString(),
        changedFields: event.changedFields || event.ChangeEventHeader?.changedFields,
        data: event.data || event,
      });

      return new Response(
        JSON.stringify({ success: true, queued: 1 }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    } catch (error: any) {
      console.error("CDC webhook error:", error);
      return new Response(
        JSON.stringify({ error: error.message }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }
  }),
});

/**
 * Get CDC sync status
 */
http.route({
  path: "/webhooks/salesforce/cdc/status",
  method: "GET",
  handler: httpAction(async (ctx) => {
    try {
      const stats = await ctx.runQuery(api.salesforce.getSyncStats, {});
      return new Response(JSON.stringify(stats), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    } catch (error: any) {
      return new Response(
        JSON.stringify({ error: error.message }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }
  }),
});

/**
 * Get connector configuration
 */
http.route({
  path: "/webhooks/salesforce/config",
  method: "GET",
  handler: httpAction(async (ctx) => {
    try {
      const config = await ctx.runQuery(api.salesforce.getConfig, {});
      return new Response(JSON.stringify(config), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    } catch (error: any) {
      return new Response(
        JSON.stringify({ error: error.message }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }
  }),
});

// ============================================================================
// HEALTH CHECK
// ============================================================================

http.route({
  path: "/health",
  method: "GET",
  handler: httpAction(async () => {
    return new Response(
      JSON.stringify({
        status: "ok",
        timestamp: new Date().toISOString(),
        service: "convex-salesforce-connector",
      }),
      {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }
    );
  }),
});

export default http;
