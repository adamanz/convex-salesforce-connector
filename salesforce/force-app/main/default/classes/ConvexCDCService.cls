/**
 * ConvexCDCService
 * Handles sending CDC (Change Data Capture) events to Convex webhook
 *
 * SETUP:
 * 1. Update CONVEX_WEBHOOK_URL with your Convex deployment URL
 * 2. Add your Convex URL to Remote Site Settings
 * 3. Enable CDC for desired objects in Setup > Change Data Capture
 */
public class ConvexCDCService {

    // ============================================================================
    // CONFIGURATION - UPDATE THIS WITH YOUR CONVEX URL
    // ============================================================================

    // Your Convex deployment webhook URL
    // Format: https://<your-deployment>.convex.site/webhooks/salesforce/cdc
    private static final String CONVEX_WEBHOOK_URL = 'https://YOUR_DEPLOYMENT.convex.site/webhooks/salesforce/cdc';

    // ============================================================================
    // MAIN PROCESSING METHODS
    // ============================================================================

    /**
     * Process a list of change events from any CDC trigger
     * Call this from your CDC triggers:
     *
     * trigger AccountCDCTrigger on AccountChangeEvent (after insert) {
     *     ConvexCDCService.processChangeEvents(Trigger.new, 'Account');
     * }
     */
    public static void processChangeEvents(List<SObject> changeEvents, String objectType) {
        if (changeEvents == null || changeEvents.isEmpty()) return;

        List<CDCEventPayload> events = new List<CDCEventPayload>();

        for (SObject evt : changeEvents) {
            EventBus.ChangeEventHeader header = (EventBus.ChangeEventHeader) evt.get('ChangeEventHeader');
            if (header == null) continue;

            CDCEventPayload payload = new CDCEventPayload();
            payload.objectType = objectType;
            payload.changeType = header.changeType;
            payload.recordId = header.recordIds[0];
            payload.replayId = String.valueOf(header.sequenceNumber);
            payload.changedFields = header.changedFields;
            payload.data = extractRecordData(evt);

            events.add(payload);
        }

        if (!events.isEmpty()) {
            // Queue async callout (required for triggers)
            System.enqueueJob(new ConvexCDCQueueable(events));
        }
    }

    /**
     * Process a single change event (alternative method)
     */
    public static void processChangeEvent(String objectType, EventBus.ChangeEventHeader header, Map<String, Object> recordData) {
        CDCEventPayload payload = new CDCEventPayload();
        payload.objectType = objectType;
        payload.changeType = header.changeType;
        payload.recordId = header.recordIds[0];
        payload.replayId = String.valueOf(header.sequenceNumber);
        payload.changedFields = header.changedFields;
        payload.data = recordData;

        System.enqueueJob(new ConvexCDCQueueable(new List<CDCEventPayload>{ payload }));
    }

    // ============================================================================
    // HELPER METHODS
    // ============================================================================

    /**
     * Extract all populated field data from a change event
     */
    private static Map<String, Object> extractRecordData(SObject evt) {
        Map<String, Object> data = new Map<String, Object>();
        Map<String, Object> fieldsMap = evt.getPopulatedFieldsAsMap();

        for (String fieldName : fieldsMap.keySet()) {
            if (fieldName != 'ChangeEventHeader') {
                data.put(fieldName, fieldsMap.get(fieldName));
            }
        }

        return data;
    }

    // ============================================================================
    // QUEUEABLE FOR ASYNC CALLOUT
    // ============================================================================

    /**
     * Queueable class to handle async HTTP callout
     * Required because triggers cannot make direct callouts
     */
    public class ConvexCDCQueueable implements Queueable, Database.AllowsCallouts {
        private List<CDCEventPayload> events;

        public ConvexCDCQueueable(List<CDCEventPayload> events) {
            this.events = events;
        }

        public void execute(QueueableContext context) {
            try {
                sendToConvex(events);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'ConvexCDC Error: ' + e.getMessage());
                System.debug(LoggingLevel.ERROR, 'Stack Trace: ' + e.getStackTraceString());
            }
        }
    }

    /**
     * Send events to Convex webhook
     */
    public static void sendToConvex(List<CDCEventPayload> events) {
        if (events == null || events.isEmpty()) return;

        // Build payload (single event or batch)
        Map<String, Object> payload = new Map<String, Object>();

        if (events.size() == 1) {
            payload = events[0].toMap();
        } else {
            List<Map<String, Object>> eventMaps = new List<Map<String, Object>>();
            for (CDCEventPayload evt : events) {
                eventMaps.add(evt.toMap());
            }
            payload.put('events', eventMaps);
        }

        // Make HTTP request
        HttpRequest req = new HttpRequest();
        req.setEndpoint(CONVEX_WEBHOOK_URL);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(payload));
        req.setTimeout(30000);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200) {
            System.debug(LoggingLevel.ERROR, 'Convex webhook failed: ' + res.getStatusCode() + ' - ' + res.getBody());
            throw new ConvexCDCException('Webhook failed with status: ' + res.getStatusCode());
        }

        System.debug('Convex CDC: Sent ' + events.size() + ' events successfully');
    }

    // ============================================================================
    // DATA CLASSES
    // ============================================================================

    /**
     * Payload structure for CDC events
     */
    public class CDCEventPayload {
        public String objectType;
        public String changeType;
        public String recordId;
        public String replayId;
        public List<String> changedFields;
        public Map<String, Object> data;

        public Map<String, Object> toMap() {
            return new Map<String, Object>{
                'objectType' => objectType,
                'changeType' => changeType,
                'recordId' => recordId,
                'replayId' => replayId,
                'changedFields' => changedFields,
                'data' => data
            };
        }
    }

    public class ConvexCDCException extends Exception {}
}
