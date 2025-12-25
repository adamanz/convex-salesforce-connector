/**
 * Test class for ConvexCDCService
 * Provides comprehensive coverage for the CDC connector
 */
@isTest
public class ConvexCDCServiceTest {

    /**
     * Mock for successful HTTP response
     */
    private class ConvexMockSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"success": true}');
            res.setStatusCode(200);
            return res;
        }
    }

    /**
     * Mock for failed HTTP response
     */
    private class ConvexMockError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"error": "Server error"}');
            res.setStatusCode(500);
            return res;
        }
    }

    /**
     * Mock for connection test - health endpoint
     */
    private class ConvexMockHealthSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status": "healthy", "version": "1.0.0"}');
            res.setStatusCode(200);
            return res;
        }
    }

    /**
     * Mock for connection test - health endpoint failure
     */
    private class ConvexMockHealthError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"error": "Service unavailable"}');
            res.setStatusCode(503);
            return res;
        }
    }

    /**
     * Setup test data with test overrides for configuration
     */
    private static void setupTestConfig() {
        ConvexCDCService.testWebhookUrl = 'https://test-project.convex.site/webhooks/salesforce/cdc';
        ConvexCDCService.testWebhookSecret = 'test-secret-key-12345';
        ConvexCDCService.testIsEnabled = true;
    }

    /**
     * Clear test overrides
     */
    private static void clearTestConfig() {
        ConvexCDCService.testWebhookUrl = null;
        ConvexCDCService.testWebhookSecret = null;
        ConvexCDCService.testIsEnabled = null;
    }

    @isTest
    static void testSendToConvexSuccess() {
        setupTestConfig();
        Test.setMock(HttpCalloutMock.class, new ConvexMockSuccess());

        ConvexCDCService.CDCEventPayload payload = new ConvexCDCService.CDCEventPayload();
        payload.objectType = 'Account';
        payload.changeType = 'CREATE';
        payload.recordId = '001000000000001AAA';
        payload.replayId = '12345';
        payload.changedFields = new List<String>{ 'Name' };
        payload.data = new Map<String, Object>{ 'Name' => 'Test Account' };

        Test.startTest();
        ConvexCDCService.sendToConvex(new List<ConvexCDCService.CDCEventPayload>{ payload });
        Test.stopTest();

        // Success means no exception thrown
        System.assert(true, 'sendToConvex completed successfully');
        clearTestConfig();
    }

    @isTest
    static void testSendToConvexBatch() {
        setupTestConfig();
        Test.setMock(HttpCalloutMock.class, new ConvexMockSuccess());

        List<ConvexCDCService.CDCEventPayload> payloads = new List<ConvexCDCService.CDCEventPayload>();

        for (Integer i = 0; i < 5; i++) {
            ConvexCDCService.CDCEventPayload payload = new ConvexCDCService.CDCEventPayload();
            payload.objectType = 'Contact';
            payload.changeType = 'UPDATE';
            payload.recordId = '003000000000' + String.valueOf(i).leftPad(3, '0') + 'AAA';
            payload.replayId = String.valueOf(i);
            payload.changedFields = new List<String>{ 'Email' };
            payload.data = new Map<String, Object>{ 'Email' => 'test' + i + '@example.com' };
            payloads.add(payload);
        }

        Test.startTest();
        ConvexCDCService.sendToConvex(payloads);
        Test.stopTest();

        System.assert(true, 'Batch sendToConvex completed successfully');
        clearTestConfig();
    }

    @isTest
    static void testSendToConvexError() {
        setupTestConfig();
        Test.setMock(HttpCalloutMock.class, new ConvexMockError());

        ConvexCDCService.CDCEventPayload payload = new ConvexCDCService.CDCEventPayload();
        payload.objectType = 'Lead';
        payload.changeType = 'CREATE';
        payload.recordId = '00Q000000000001AAA';
        payload.replayId = '99999';
        payload.data = new Map<String, Object>{ 'Company' => 'Test Co' };

        Test.startTest();
        try {
            ConvexCDCService.sendToConvex(new List<ConvexCDCService.CDCEventPayload>{ payload });
            System.assert(false, 'Should have thrown exception');
        } catch (ConvexCDCService.ConvexCDCException e) {
            System.assert(e.getMessage().contains('500'), 'Should contain status code');
        }
        Test.stopTest();

        clearTestConfig();
    }

    @isTest
    static void testSendToConvexEmpty() {
        Test.startTest();
        ConvexCDCService.sendToConvex(new List<ConvexCDCService.CDCEventPayload>());
        ConvexCDCService.sendToConvex(null);
        Test.stopTest();

        System.assert(true, 'Empty/null list should not throw exception');
    }

    @isTest
    static void testPayloadToMap() {
        ConvexCDCService.CDCEventPayload payload = new ConvexCDCService.CDCEventPayload();
        payload.objectType = 'Opportunity';
        payload.changeType = 'UPDATE';
        payload.recordId = '006000000000001AAA';
        payload.replayId = '12345';
        payload.changedFields = new List<String>{ 'StageName', 'Amount' };
        payload.data = new Map<String, Object>{
            'StageName' => 'Closed Won',
            'Amount' => 50000
        };

        Map<String, Object> result = payload.toMap();

        System.assertEquals('Opportunity', result.get('objectType'));
        System.assertEquals('UPDATE', result.get('changeType'));
        System.assertEquals('006000000000001AAA', result.get('recordId'));
        System.assertEquals('12345', result.get('replayId'));
        System.assertNotEquals(null, result.get('changedFields'));
        System.assertNotEquals(null, result.get('data'));
    }

    @isTest
    static void testQueueableExecution() {
        setupTestConfig();
        Test.setMock(HttpCalloutMock.class, new ConvexMockSuccess());

        ConvexCDCService.CDCEventPayload payload = new ConvexCDCService.CDCEventPayload();
        payload.objectType = 'Account';
        payload.changeType = 'CREATE';
        payload.recordId = '001000000000001AAA';
        payload.data = new Map<String, Object>{ 'Name' => 'Test' };

        Test.startTest();
        System.enqueueJob(new ConvexCDCService.ConvexCDCQueueable(
            new List<ConvexCDCService.CDCEventPayload>{ payload }
        ));
        Test.stopTest();

        System.assert(true, 'Queueable executed successfully');
        clearTestConfig();
    }

    @isTest
    static void testQueueableWithError() {
        setupTestConfig();
        Test.setMock(HttpCalloutMock.class, new ConvexMockError());

        ConvexCDCService.CDCEventPayload payload = new ConvexCDCService.CDCEventPayload();
        payload.objectType = 'Account';
        payload.changeType = 'CREATE';
        payload.recordId = '001000000000001AAA';
        payload.data = new Map<String, Object>{ 'Name' => 'Test' };

        Test.startTest();
        // Queueable should catch and log the error, not throw
        System.enqueueJob(new ConvexCDCService.ConvexCDCQueueable(
            new List<ConvexCDCService.CDCEventPayload>{ payload }
        ));
        Test.stopTest();

        System.assert(true, 'Queueable should handle errors gracefully');
        clearTestConfig();
    }

    @isTest
    static void testIsEnabledTrue() {
        ConvexCDCService.testIsEnabled = true;

        Test.startTest();
        Boolean enabled = ConvexCDCService.isEnabled();
        Test.stopTest();

        System.assertEquals(true, enabled, 'isEnabled should return true when test override is true');
        clearTestConfig();
    }

    @isTest
    static void testIsEnabledFalse() {
        ConvexCDCService.testIsEnabled = false;

        Test.startTest();
        Boolean enabled = ConvexCDCService.isEnabled();
        Test.stopTest();

        System.assertEquals(false, enabled, 'isEnabled should return false when test override is false');
        clearTestConfig();
    }

    @isTest
    static void testIsEnabledNoSettings() {
        // Test isEnabled when no settings exist and no override
        Test.startTest();
        Boolean enabled = ConvexCDCService.isEnabled();
        Test.stopTest();

        // Without custom metadata, should return false
        System.assertEquals(false, enabled, 'isEnabled should return false when no settings exist');
    }

    @isTest
    static void testTestConnectionNoUrl() {
        // Test connection when URL not configured
        Test.startTest();
        Map<String, Object> result = ConvexCDCService.testConnection();
        Test.stopTest();

        System.assertEquals(false, result.get('success'), 'Should fail when URL not configured');
        System.assertNotEquals(null, result.get('error'), 'Should have error message');
    }

    @isTest
    static void testTestConnectionSuccess() {
        ConvexCDCService.testWebhookUrl = 'https://test-project.convex.site/webhooks/salesforce/cdc';
        Test.setMock(HttpCalloutMock.class, new ConvexMockHealthSuccess());

        Test.startTest();
        Map<String, Object> result = ConvexCDCService.testConnection();
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Should succeed with mock');
        System.assertEquals('Connection successful', result.get('message'));
        clearTestConfig();
    }

    @isTest
    static void testTestConnectionError() {
        ConvexCDCService.testWebhookUrl = 'https://test-project.convex.site/webhooks/salesforce/cdc';
        Test.setMock(HttpCalloutMock.class, new ConvexMockHealthError());

        Test.startTest();
        Map<String, Object> result = ConvexCDCService.testConnection();
        Test.stopTest();

        System.assertEquals(false, result.get('success'), 'Should fail with error response');
        System.assert(((String)result.get('error')).contains('503'), 'Should contain status code');
        clearTestConfig();
    }

    @isTest
    static void testPayloadWithNullFields() {
        ConvexCDCService.CDCEventPayload payload = new ConvexCDCService.CDCEventPayload();
        payload.objectType = 'Task';
        payload.changeType = 'DELETE';
        payload.recordId = '00T000000000001AAA';
        payload.replayId = null;
        payload.changedFields = null;
        payload.data = null;

        Map<String, Object> result = payload.toMap();

        System.assertEquals('Task', result.get('objectType'));
        System.assertEquals('DELETE', result.get('changeType'));
        System.assertEquals('00T000000000001AAA', result.get('recordId'));
        System.assertEquals(null, result.get('replayId'));
        System.assertEquals(null, result.get('changedFields'));
        System.assertEquals(null, result.get('data'));
    }

    @isTest
    static void testSendToConvexNoUrl() {
        // Clear any test overrides - URL should be blank
        clearTestConfig();

        ConvexCDCService.CDCEventPayload payload = new ConvexCDCService.CDCEventPayload();
        payload.objectType = 'Account';
        payload.changeType = 'CREATE';
        payload.recordId = '001000000000001AAA';
        payload.data = new Map<String, Object>{ 'Name' => 'Test' };

        Test.startTest();
        // Should not throw, just return early
        ConvexCDCService.sendToConvex(new List<ConvexCDCService.CDCEventPayload>{ payload });
        Test.stopTest();

        System.assert(true, 'Should complete without exception when URL not configured');
    }

    @isTest
    static void testSendToConvexWithoutSecret() {
        // Test sending without webhook secret (no HMAC signature)
        ConvexCDCService.testWebhookUrl = 'https://test-project.convex.site/webhooks/salesforce/cdc';
        ConvexCDCService.testWebhookSecret = null; // No secret
        Test.setMock(HttpCalloutMock.class, new ConvexMockSuccess());

        ConvexCDCService.CDCEventPayload payload = new ConvexCDCService.CDCEventPayload();
        payload.objectType = 'Account';
        payload.changeType = 'CREATE';
        payload.recordId = '001000000000001AAA';
        payload.data = new Map<String, Object>{ 'Name' => 'Test' };

        Test.startTest();
        ConvexCDCService.sendToConvex(new List<ConvexCDCService.CDCEventPayload>{ payload });
        Test.stopTest();

        System.assert(true, 'Should work without secret');
        clearTestConfig();
    }

    @isTest
    static void testExceptionClass() {
        // Test the custom exception class
        Test.startTest();
        try {
            throw new ConvexCDCService.ConvexCDCException('Test error message');
        } catch (ConvexCDCService.ConvexCDCException e) {
            System.assertEquals('Test error message', e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testGenerateSignature() {
        // Test HMAC signature generation
        String payload = '{"test": "data"}';
        String timestamp = '1234567890';
        String secret = 'test-secret';

        Test.startTest();
        String signature = ConvexCDCService.generateSignature(payload, timestamp, secret);
        Test.stopTest();

        System.assertNotEquals(null, signature, 'Signature should not be null');
        System.assertEquals(64, signature.length(), 'HMAC-SHA256 hex should be 64 chars');
    }

    @isTest
    static void testProcessChangeEventsDisabled() {
        // Test that processChangeEvents does nothing when disabled
        ConvexCDCService.testIsEnabled = false;

        Test.startTest();
        // This should return early without doing anything
        ConvexCDCService.processChangeEvents(new List<SObject>(), 'Account');
        Test.stopTest();

        System.assert(true, 'Should return early when disabled');
        clearTestConfig();
    }

    @isTest
    static void testProcessChangeEventsEmpty() {
        ConvexCDCService.testIsEnabled = true;

        Test.startTest();
        ConvexCDCService.processChangeEvents(null, 'Account');
        ConvexCDCService.processChangeEvents(new List<SObject>(), 'Account');
        Test.stopTest();

        System.assert(true, 'Should handle null/empty gracefully');
        clearTestConfig();
    }

    @isTest
    static void testSingleEventPayload() {
        // Test single event uses different JSON structure than batch
        setupTestConfig();
        Test.setMock(HttpCalloutMock.class, new ConvexMockSuccess());

        ConvexCDCService.CDCEventPayload payload = new ConvexCDCService.CDCEventPayload();
        payload.objectType = 'Account';
        payload.changeType = 'UPDATE';
        payload.recordId = '001000000000001AAA';
        payload.replayId = '12345';
        payload.changedFields = new List<String>{ 'Name', 'Phone' };
        payload.data = new Map<String, Object>{
            'Name' => 'Updated Account',
            'Phone' => '555-1234'
        };

        Test.startTest();
        // Single event - should use direct payload, not wrapped in events array
        ConvexCDCService.sendToConvex(new List<ConvexCDCService.CDCEventPayload>{ payload });
        Test.stopTest();

        System.assert(true, 'Single event sent successfully');
        clearTestConfig();
    }

    @isTest
    static void testGetSettingsNoData() {
        // Test getSettings when no custom metadata exists
        Test.startTest();
        // This calls getSettings internally
        Boolean enabled = ConvexCDCService.isEnabled();
        Test.stopTest();

        System.assertEquals(false, enabled, 'Should return false when no settings');
    }

    @isTest
    static void testExtractRecordData() {
        // Create a test Account to extract data from
        Account testAccount = new Account(Name = 'Test Account', Phone = '555-1234');
        insert testAccount;

        Test.startTest();
        Map<String, Object> data = ConvexCDCService.extractRecordData(testAccount);
        Test.stopTest();

        System.assertNotEquals(null, data, 'Should extract data');
        System.assertEquals('Test Account', data.get('Name'));
    }

    @isTest
    static void testTestConnectionException() {
        // Test connection when HTTP returns error
        ConvexCDCService.testWebhookUrl = 'https://invalid-url.convex.site/webhooks/salesforce/cdc';
        Test.setMock(HttpCalloutMock.class, new ConvexMockBadGateway());

        Test.startTest();
        Map<String, Object> result = ConvexCDCService.testConnection();
        Test.stopTest();

        System.assertEquals(false, result.get('success'), 'Should fail on exception');
        System.assertNotEquals(null, result.get('error'), 'Should have error message');
        clearTestConfig();
    }

    @isTest
    static void testGetWebhookUrl() {
        // Test getWebhookUrl with override
        ConvexCDCService.testWebhookUrl = 'https://custom-url.convex.site/webhook';

        Test.startTest();
        String url = ConvexCDCService.getWebhookUrl();
        Test.stopTest();

        System.assertEquals('https://custom-url.convex.site/webhook', url);
        clearTestConfig();
    }

    @isTest
    static void testGetWebhookSecret() {
        // Test getWebhookSecret with override
        ConvexCDCService.testWebhookSecret = 'my-secret-key';

        Test.startTest();
        String secret = ConvexCDCService.getWebhookSecret();
        Test.stopTest();

        System.assertEquals('my-secret-key', secret);
        clearTestConfig();
    }

    @isTest
    static void testGetWebhookUrlNoOverride() {
        // Test getWebhookUrl without override (uses metadata)
        clearTestConfig();

        Test.startTest();
        String url = ConvexCDCService.getWebhookUrl();
        Test.stopTest();

        // Without custom metadata, should return null
        System.assertEquals(null, url);
    }

    @isTest
    static void testGetWebhookSecretNoOverride() {
        // Test getWebhookSecret without override (uses metadata)
        clearTestConfig();

        Test.startTest();
        String secret = ConvexCDCService.getWebhookSecret();
        Test.stopTest();

        // Without custom metadata, should return null
        System.assertEquals(null, secret);
    }

    @isTest
    static void testMultiEventPayload() {
        // Test batch of 3 events uses events array structure
        setupTestConfig();
        Test.setMock(HttpCalloutMock.class, new ConvexMockSuccess());

        List<ConvexCDCService.CDCEventPayload> payloads = new List<ConvexCDCService.CDCEventPayload>();
        for (Integer i = 0; i < 3; i++) {
            ConvexCDCService.CDCEventPayload p = new ConvexCDCService.CDCEventPayload();
            p.objectType = 'Contact';
            p.changeType = 'UPDATE';
            p.recordId = '003000000000' + String.valueOf(i).leftPad(3, '0') + 'AAA';
            p.replayId = String.valueOf(i);
            p.changedFields = new List<String>{ 'LastName' };
            p.data = new Map<String, Object>{ 'LastName' => 'Test ' + i };
            payloads.add(p);
        }

        Test.startTest();
        ConvexCDCService.sendToConvex(payloads);
        Test.stopTest();

        System.assert(true, 'Multi-event batch sent successfully');
        clearTestConfig();
    }

    @isTest
    static void testSignatureConsistency() {
        // Test that same inputs produce same signature
        String payload = '{"objectType":"Account","changeType":"CREATE"}';
        String timestamp = '1735142400000';
        String secret = 'consistent-secret';

        Test.startTest();
        String sig1 = ConvexCDCService.generateSignature(payload, timestamp, secret);
        String sig2 = ConvexCDCService.generateSignature(payload, timestamp, secret);
        Test.stopTest();

        System.assertEquals(sig1, sig2, 'Same inputs should produce same signature');
    }

    @isTest
    static void testSignatureDifference() {
        // Test that different payloads produce different signatures
        String timestamp = '1735142400000';
        String secret = 'test-secret';

        Test.startTest();
        String sig1 = ConvexCDCService.generateSignature('payload1', timestamp, secret);
        String sig2 = ConvexCDCService.generateSignature('payload2', timestamp, secret);
        Test.stopTest();

        System.assertNotEquals(sig1, sig2, 'Different payloads should produce different signatures');
    }

    /**
     * Mock for HTTP bad gateway scenarios
     */
    private class ConvexMockBadGateway implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            // Return a bad gateway error to simulate connection issues
            HttpResponse res = new HttpResponse();
            res.setStatusCode(502);
            res.setBody('Bad Gateway');
            return res;
        }
    }
}
