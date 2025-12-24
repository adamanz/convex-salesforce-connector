/**
 * ConvexCDCService
 * Handles sending CDC (Change Data Capture) events to Convex webhook
 * with HMAC signature verification for security.
 *
 * SETUP:
 * 1. Go to the "Convex Connector Setup" tab in Salesforce
 * 2. Enter your Convex webhook URL and secret
 * 3. Enable CDC for desired objects in Setup > Change Data Capture
 */
public class ConvexCDCService {

    // ============================================================================
    // CONFIGURATION - Stored in Custom Metadata or Custom Settings
    // ============================================================================

    // Get webhook URL from Custom Metadata
    private static String getWebhookUrl() {
        Convex_Connector_Settings__mdt settings = getSettings();
        return settings?.Webhook_URL__c;
    }

    // Get webhook secret for HMAC signing
    private static String getWebhookSecret() {
        Convex_Connector_Settings__mdt settings = getSettings();
        return settings?.Webhook_Secret__c;
    }

    // Get settings from Custom Metadata
    private static Convex_Connector_Settings__mdt getSettings() {
        List<Convex_Connector_Settings__mdt> settings = [
            SELECT Webhook_URL__c, Webhook_Secret__c, Is_Enabled__c
            FROM Convex_Connector_Settings__mdt
            WHERE DeveloperName = 'Default'
            LIMIT 1
        ];
        return settings.isEmpty() ? null : settings[0];
    }

    // Check if connector is enabled
    public static Boolean isEnabled() {
        Convex_Connector_Settings__mdt settings = getSettings();
        return settings != null && settings.Is_Enabled__c == true;
    }

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
        if (!isEnabled()) {
            System.debug('Convex CDC Connector is disabled');
            return;
        }

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
        if (!isEnabled()) return;

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

    /**
     * Generate HMAC-SHA256 signature
     */
    private static String generateSignature(String payload, String timestamp, String secret) {
        String signedPayload = timestamp + '.' + payload;
        Blob hmac = Crypto.generateMac(
            'HmacSHA256',
            Blob.valueOf(signedPayload),
            Blob.valueOf(secret)
        );
        return EncodingUtil.convertToHex(hmac);
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
     * Send events to Convex webhook with HMAC signature
     */
    public static void sendToConvex(List<CDCEventPayload> events) {
        if (events == null || events.isEmpty()) return;

        String webhookUrl = getWebhookUrl();
        String webhookSecret = getWebhookSecret();

        if (String.isBlank(webhookUrl)) {
            System.debug(LoggingLevel.ERROR, 'Convex webhook URL not configured');
            return;
        }

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

        String jsonPayload = JSON.serialize(payload);
        String timestamp = String.valueOf(System.currentTimeMillis());

        // Make HTTP request
        HttpRequest req = new HttpRequest();
        req.setEndpoint(webhookUrl);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('X-Convex-Timestamp', timestamp);

        // Add HMAC signature if secret is configured
        if (String.isNotBlank(webhookSecret)) {
            String signature = generateSignature(jsonPayload, timestamp, webhookSecret);
            req.setHeader('X-Convex-Signature', signature);
        }

        req.setBody(jsonPayload);
        req.setTimeout(30000);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200) {
            System.debug(LoggingLevel.ERROR, 'Convex webhook failed: ' + res.getStatusCode() + ' - ' + res.getBody());
            throw new ConvexCDCException('Webhook failed with status: ' + res.getStatusCode());
        }

        System.debug('Convex CDC: Sent ' + events.size() + ' events successfully');
    }

    /**
     * Test the webhook connection
     */
    @AuraEnabled
    public static Map<String, Object> testConnection() {
        Map<String, Object> result = new Map<String, Object>();

        try {
            String webhookUrl = getWebhookUrl();
            if (String.isBlank(webhookUrl)) {
                result.put('success', false);
                result.put('error', 'Webhook URL not configured');
                return result;
            }

            // Test with health endpoint
            String healthUrl = webhookUrl.replace('/webhooks/salesforce/cdc', '/health');

            HttpRequest req = new HttpRequest();
            req.setEndpoint(healthUrl);
            req.setMethod('GET');
            req.setTimeout(10000);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                result.put('success', true);
                result.put('message', 'Connection successful');
                result.put('response', res.getBody());
            } else {
                result.put('success', false);
                result.put('error', 'HTTP ' + res.getStatusCode() + ': ' + res.getBody());
            }
        } catch (Exception e) {
            result.put('success', false);
            result.put('error', e.getMessage());
        }

        return result;
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
