/**
 * Test class for ConvexCDCService
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

    @isTest
    static void testSendToConvexSuccess() {
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
    }

    @isTest
    static void testSendToConvexBatch() {
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
    }

    @isTest
    static void testSendToConvexError() {
        Test.setMock(HttpCalloutMock.class, new ConvexMockError());

        ConvexCDCService.CDCEventPayload payload = new ConvexCDCService.CDCEventPayload();
        payload.objectType = 'Lead';
        payload.changeType = 'CREATE';
        payload.recordId = '00Q000000000001AAA';
        payload.replayId = '99999';
        payload.data = new Map<String, Object>{};

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            ConvexCDCService.sendToConvex(new List<ConvexCDCService.CDCEventPayload>{ payload });
        } catch (ConvexCDCService.ConvexCDCException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('500'), 'Exception should contain status code');
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Exception should be thrown for error response');
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
    }
}
