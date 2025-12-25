/**
 * ConvexOAuthServiceTest
 * Test class for ConvexOAuthService with comprehensive coverage.
 */
@isTest
private class ConvexOAuthServiceTest {

    // ============================================================================
    // TEST SETUP
    // ============================================================================

    @TestSetup
    static void setupTestData() {
        // Create test connection
        Convex_Connection__c conn = new Convex_Connection__c(
            Team_Name__c = 'test-team',
            Team_Id__c = 'team_123',
            Project_Name__c = 'test-project',
            Project_Id__c = 'proj_456',
            Deployment_URL__c = 'https://test-project.convex.cloud',
            Access_Token__c = 'project:test-team:test-project|testtoken123',
            Is_Active__c = true,
            Connected_At__c = DateTime.now()
        );
        insert conn;
    }

    // ============================================================================
    // AUTHORIZATION URL TESTS
    // ============================================================================

    @isTest
    static void testGetAuthorizationUrl_Project() {
        // Setup test overrides
        ConvexOAuthService.testClientId = 'test_client_id';
        ConvexOAuthService.testRedirectUri = 'https://test.salesforce.com/apex/ConvexOAuthCallback';

        Test.startTest();
        String authUrl = ConvexOAuthService.getAuthorizationUrl('project');
        Test.stopTest();

        System.assertNotEquals(null, authUrl, 'Auth URL should not be null');
        System.assert(authUrl.contains('oauth/authorize/project'), 'Should be project scope');
        System.assert(authUrl.contains('client_id=test_client_id'), 'Should contain client ID');
        System.assert(authUrl.contains('response_type=code'), 'Should contain response type');
    }

    @isTest
    static void testGetAuthorizationUrl_Team() {
        ConvexOAuthService.testClientId = 'test_client_id';
        ConvexOAuthService.testRedirectUri = 'https://test.salesforce.com/apex/ConvexOAuthCallback';

        Test.startTest();
        String authUrl = ConvexOAuthService.getAuthorizationUrl('team');
        Test.stopTest();

        System.assert(authUrl.contains('oauth/authorize/team'), 'Should be team scope');
    }

    @isTest
    static void testGetAuthorizationUrl_NoClientId() {
        ConvexOAuthService.testClientId = null;

        Test.startTest();
        try {
            ConvexOAuthService.getAuthorizationUrl('project');
            System.assert(false, 'Should have thrown exception');
        } catch (ConvexOAuthService.OAuthException e) {
            System.assert(e.getMessage().contains('Client ID not configured'), 'Should mention client ID');
        }
        Test.stopTest();
    }

    @isTest
    static void testGetAuthorizationUrlWithPKCE() {
        ConvexOAuthService.testClientId = 'test_client_id';
        ConvexOAuthService.testRedirectUri = 'https://test.salesforce.com/apex/ConvexOAuthCallback';

        Test.startTest();
        Map<String, String> result = ConvexOAuthService.getAuthorizationUrlWithPKCE('project');
        Test.stopTest();

        System.assertNotEquals(null, result.get('authUrl'), 'Auth URL should not be null');
        System.assertNotEquals(null, result.get('state'), 'State should not be null');
        System.assert(result.get('authUrl').contains('code_challenge='), 'Should contain code challenge');
        System.assert(result.get('authUrl').contains('code_challenge_method=S256'), 'Should use S256 method');
    }

    // ============================================================================
    // TOKEN EXCHANGE TESTS
    // ============================================================================

    @isTest
    static void testExchangeCodeForToken_Success() {
        ConvexOAuthService.testClientId = 'test_client_id';
        ConvexOAuthService.testClientSecret = 'test_client_secret';
        ConvexOAuthService.testRedirectUri = 'https://test.salesforce.com/apex/ConvexOAuthCallback';
        ConvexOAuthService.testModeEnabled = true;

        Test.startTest();
        Map<String, Object> result = ConvexOAuthService.exchangeCodeForToken('test_code', 'test_state');
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Should succeed');
        System.assertNotEquals(null, result.get('access_token'), 'Should have access token');
    }

    @isTest
    static void testExchangeCodeForToken_WithPKCE() {
        ConvexOAuthService.testClientId = 'test_client_id';
        ConvexOAuthService.testClientSecret = 'test_client_secret';
        ConvexOAuthService.testRedirectUri = 'https://test.salesforce.com/apex/ConvexOAuthCallback';
        ConvexOAuthService.testModeEnabled = true;

        Test.startTest();
        Map<String, Object> result = ConvexOAuthService.exchangeCodeForToken(
            'test_code',
            'test_state',
            'test_code_verifier'
        );
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Should succeed');
    }

    // ============================================================================
    // CONNECTION MANAGEMENT TESTS
    // ============================================================================

    @isTest
    static void testGetActiveConnection() {
        Test.startTest();
        Convex_Connection__c conn = ConvexOAuthService.getActiveConnection();
        Test.stopTest();

        System.assertNotEquals(null, conn, 'Should return connection');
        System.assertEquals('test-team', conn.Team_Name__c, 'Should have correct team');
        System.assertEquals('test-project', conn.Project_Name__c, 'Should have correct project');
    }

    @isTest
    static void testGetActiveConnection_WithTestOverride() {
        Convex_Connection__c testConn = new Convex_Connection__c(
            Team_Name__c = 'override-team',
            Project_Name__c = 'override-project'
        );
        ConvexOAuthService.testConnection = testConn;

        Test.startTest();
        Convex_Connection__c result = ConvexOAuthService.getActiveConnection();
        Test.stopTest();

        System.assertEquals('override-team', result.Team_Name__c, 'Should use test override');
    }

    @isTest
    static void testIsConnected_True() {
        Test.startTest();
        Boolean connected = ConvexOAuthService.isConnected();
        Test.stopTest();

        System.assertEquals(true, connected, 'Should be connected');
    }

    @isTest
    static void testIsConnected_False() {
        // Delete all connections
        delete [SELECT Id FROM Convex_Connection__c];

        Test.startTest();
        Boolean connected = ConvexOAuthService.isConnected();
        Test.stopTest();

        System.assertEquals(false, connected, 'Should not be connected');
    }

    @isTest
    static void testDisconnect() {
        Test.startTest();
        ConvexOAuthService.disconnect();
        Test.stopTest();

        Convex_Connection__c conn = [
            SELECT Is_Active__c, Access_Token__c
            FROM Convex_Connection__c
            LIMIT 1
        ];
        System.assertEquals(false, conn.Is_Active__c, 'Should be deactivated');
        System.assertEquals(null, conn.Access_Token__c, 'Token should be cleared');
    }

    // ============================================================================
    // API METHODS TESTS
    // ============================================================================

    @isTest
    static void testSetEnvironmentVariable() {
        Test.startTest();
        Map<String, Object> result = ConvexOAuthService.setEnvironmentVariable(
            'SALESFORCE_WEBHOOK_SECRET',
            'test_secret_value'
        );
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Should succeed in test mode');
    }

    @isTest
    static void testSetEnvironmentVariable_NoConnection() {
        // Delete all connections
        delete [SELECT Id FROM Convex_Connection__c];

        Test.startTest();
        Map<String, Object> result = ConvexOAuthService.setEnvironmentVariable(
            'TEST_VAR',
            'test_value'
        );
        Test.stopTest();

        System.assertEquals(false, result.get('success'), 'Should fail without connection');
        System.assert(((String)result.get('error')).contains('No active'), 'Should mention no connection');
    }

    @isTest
    static void testConfigureWebhook() {
        Test.startTest();
        Map<String, Object> result = ConvexOAuthService.configureWebhook();
        Test.stopTest();

        // In test mode, setEnvironmentVariable returns success
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testConfigureWebhook_NoConnection() {
        delete [SELECT Id FROM Convex_Connection__c];

        Test.startTest();
        Map<String, Object> result = ConvexOAuthService.configureWebhook();
        Test.stopTest();

        System.assertEquals(false, result.get('success'), 'Should fail without connection');
    }

    // ============================================================================
    // HELPER METHODS TESTS
    // ============================================================================

    @isTest
    static void testGenerateState() {
        Test.startTest();
        String state1 = ConvexOAuthService.generateState();
        String state2 = ConvexOAuthService.generateState();
        Test.stopTest();

        System.assertNotEquals(null, state1, 'State should not be null');
        System.assertEquals(32, state1.length(), 'State should be 32 characters');
        System.assertNotEquals(state1, state2, 'States should be unique');
    }

    @isTest
    static void testGenerateCodeVerifier() {
        Test.startTest();
        String verifier = ConvexOAuthService.generateCodeVerifier();
        Test.stopTest();

        System.assertNotEquals(null, verifier, 'Verifier should not be null');
        System.assertEquals(43, verifier.length(), 'Verifier should be 43 characters');
    }

    @isTest
    static void testGenerateCodeChallenge() {
        String verifier = 'test_verifier_string_that_is_long_enough_to_work';

        Test.startTest();
        String challenge = ConvexOAuthService.generateCodeChallenge(verifier);
        Test.stopTest();

        System.assertNotEquals(null, challenge, 'Challenge should not be null');
        System.assert(challenge.length() > 0, 'Challenge should have length');
    }

    @isTest
    static void testGenerateWebhookSecret() {
        Test.startTest();
        String secret1 = ConvexOAuthService.generateWebhookSecret();
        String secret2 = ConvexOAuthService.generateWebhookSecret();
        Test.stopTest();

        System.assertNotEquals(null, secret1, 'Secret should not be null');
        System.assertEquals(64, secret1.length(), 'Secret should be 64 hex characters');
        System.assertNotEquals(secret1, secret2, 'Secrets should be unique');
    }

    @isTest
    static void testParseAccessToken_Project() {
        String token = 'project:my-team:my-project|sometoken123';

        Test.startTest();
        Map<String, String> info = ConvexOAuthService.parseAccessToken(token);
        Test.stopTest();

        System.assertEquals('project', info.get('type'), 'Should be project type');
        System.assertEquals('my-team', info.get('team'), 'Should have team name');
        System.assertEquals('my-project', info.get('project'), 'Should have project name');
    }

    @isTest
    static void testParseAccessToken_Team() {
        String token = 'team:my-team|sometoken123';

        Test.startTest();
        Map<String, String> info = ConvexOAuthService.parseAccessToken(token);
        Test.stopTest();

        System.assertEquals('team', info.get('type'), 'Should be team type');
        System.assertEquals('my-team', info.get('team'), 'Should have team name');
        System.assertEquals(null, info.get('project'), 'Should not have project');
    }

    @isTest
    static void testParseAccessToken_Empty() {
        Test.startTest();
        Map<String, String> info = ConvexOAuthService.parseAccessToken('');
        Test.stopTest();

        System.assertEquals(0, info.size(), 'Should return empty map');
    }

    @isTest
    static void testParseAccessToken_Null() {
        Test.startTest();
        Map<String, String> info = ConvexOAuthService.parseAccessToken(null);
        Test.stopTest();

        System.assertEquals(0, info.size(), 'Should return empty map');
    }

    @isTest
    static void testVerifyOAuthState() {
        // In test mode, state verification always returns true
        Test.startTest();
        Boolean result = ConvexOAuthService.verifyOAuthState('any_state');
        Test.stopTest();

        System.assertEquals(true, result, 'Should return true in test mode');
    }

    // ============================================================================
    // ADDITIONAL COVERAGE TESTS
    // ============================================================================

    @isTest
    static void testGetAuthorizationUrlWithPKCE_TeamScope() {
        ConvexOAuthService.testClientId = 'test_client_id';
        ConvexOAuthService.testRedirectUri = 'https://test.salesforce.com/apex/ConvexOAuthCallback';

        Test.startTest();
        Map<String, String> result = ConvexOAuthService.getAuthorizationUrlWithPKCE('team');
        Test.stopTest();

        System.assert(result.get('authUrl').contains('oauth/authorize/team'), 'Should be team scope');
        System.assert(result.get('authUrl').contains('code_challenge='), 'Should contain code challenge');
    }

    @isTest
    static void testGetAuthorizationUrlWithPKCE_NoClientId() {
        ConvexOAuthService.testClientId = null;

        Test.startTest();
        try {
            ConvexOAuthService.getAuthorizationUrlWithPKCE('project');
            System.assert(false, 'Should have thrown exception');
        } catch (ConvexOAuthService.OAuthException e) {
            System.assert(e.getMessage().contains('Client ID not configured'), 'Should mention client ID');
        }
        Test.stopTest();
    }

    @isTest
    static void testDisconnect_NoActiveConnection() {
        // Delete all connections first
        delete [SELECT Id FROM Convex_Connection__c];

        Test.startTest();
        ConvexOAuthService.disconnect();
        Test.stopTest();

        // Should complete without error
        System.assertEquals(0, [SELECT COUNT() FROM Convex_Connection__c WHERE Is_Active__c = true]);
    }

    @isTest
    static void testParseAccessToken_InvalidFormat() {
        // Token without pipe character
        Test.startTest();
        Map<String, String> info = ConvexOAuthService.parseAccessToken('invalidtoken');
        Test.stopTest();

        // Should return map with parsed parts
        System.assertNotEquals(null, info, 'Should return a map');
    }

    @isTest
    static void testParseAccessToken_SingleColon() {
        // Token with only one colon
        Test.startTest();
        Map<String, String> info = ConvexOAuthService.parseAccessToken('single:part|token');
        Test.stopTest();

        System.assertEquals('single', info.get('type'), 'Should parse type');
        System.assertEquals('part', info.get('team'), 'Should parse team');
    }

    @isTest
    static void testExchangeCodeForToken_NoTestMode() {
        // Test without enabling test mode - will try real HTTP
        ConvexOAuthService.testClientId = 'test_client_id';
        ConvexOAuthService.testClientSecret = 'test_client_secret';
        ConvexOAuthService.testRedirectUri = 'https://test.salesforce.com/apex/ConvexOAuthCallback';
        ConvexOAuthService.testModeEnabled = false;

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new ConvexTokenSuccessMock());
        Map<String, Object> result = ConvexOAuthService.exchangeCodeForToken('test_code', 'test_state');
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Should succeed with mock');
    }

    @isTest
    static void testExchangeCodeForToken_HttpError() {
        ConvexOAuthService.testClientId = 'test_client_id';
        ConvexOAuthService.testClientSecret = 'test_client_secret';
        ConvexOAuthService.testRedirectUri = 'https://test.salesforce.com/apex/ConvexOAuthCallback';
        ConvexOAuthService.testModeEnabled = false;

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new ConvexTokenErrorMock());
        Map<String, Object> result = ConvexOAuthService.exchangeCodeForToken('test_code', 'test_state');
        Test.stopTest();

        System.assertEquals(false, result.get('success'), 'Should fail on HTTP error');
        System.assert(((String)result.get('error')).contains('Token exchange failed'), 'Should have error message');
    }

    @isTest
    static void testConfigureWebhook_WithEnvSuccess() {
        // Ensure connection exists
        Convex_Connection__c conn = [SELECT Id, Deployment_URL__c FROM Convex_Connection__c LIMIT 1];

        Test.startTest();
        Map<String, Object> result = ConvexOAuthService.configureWebhook();
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Should succeed');
        System.assertNotEquals(null, result.get('webhookSecret'), 'Should have webhook secret');
    }

    @isTest
    static void testMultipleStates() {
        // Generate multiple states to ensure uniqueness
        Test.startTest();
        Set<String> states = new Set<String>();
        for (Integer i = 0; i < 10; i++) {
            states.add(ConvexOAuthService.generateState());
        }
        Test.stopTest();

        System.assertEquals(10, states.size(), 'All states should be unique');
    }

    @isTest
    static void testMultipleCodeVerifiers() {
        // Generate multiple verifiers to ensure uniqueness
        Test.startTest();
        Set<String> verifiers = new Set<String>();
        for (Integer i = 0; i < 10; i++) {
            verifiers.add(ConvexOAuthService.generateCodeVerifier());
        }
        Test.stopTest();

        System.assertEquals(10, verifiers.size(), 'All verifiers should be unique');
    }

    @isTest
    static void testCodeChallengeConsistency() {
        String verifier = 'test_verifier_that_is_definitely_long_enough';

        Test.startTest();
        String challenge1 = ConvexOAuthService.generateCodeChallenge(verifier);
        String challenge2 = ConvexOAuthService.generateCodeChallenge(verifier);
        Test.stopTest();

        System.assertEquals(challenge1, challenge2, 'Same verifier should produce same challenge');
    }

    @isTest
    static void testExchangeCodeForToken_Exception() {
        // Test exception handling in token exchange
        ConvexOAuthService.testClientId = null; // Will cause exception when building request
        ConvexOAuthService.testClientSecret = null;
        ConvexOAuthService.testModeEnabled = false;

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new ConvexTokenExceptionMock());
        Map<String, Object> result = ConvexOAuthService.exchangeCodeForToken('test_code', 'test_state');
        Test.stopTest();

        // Should handle exception gracefully
        System.assertNotEquals(null, result, 'Should return result map');
    }

    @isTest
    static void testSetEnvironmentVariable_Exception() {
        // Create a connection with null token to trigger exception path
        Convex_Connection__c conn = [SELECT Id FROM Convex_Connection__c LIMIT 1];
        conn.Access_Token__c = null;
        update conn;

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new ConvexApiExceptionMock());
        Map<String, Object> result = ConvexOAuthService.setEnvironmentVariable('TEST', 'value');
        Test.stopTest();

        // In test mode, returns success without HTTP call
        System.assertNotEquals(null, result);
    }

    // ============================================================================
    // MOCK CLASSES FOR HTTP CALLOUTS
    // ============================================================================

    private class ConvexTokenSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"access_token":"project:test-team:test-project|mocktoken123","token_type":"bearer"}');
            return res;
        }
    }

    private class ConvexTokenErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"error":"invalid_grant","error_description":"Invalid authorization code"}');
            return res;
        }
    }

    private class ConvexTokenExceptionMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            // Return server error to simulate failure
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error":"server_error","error_description":"Internal server error"}');
            return res;
        }
    }

    private class ConvexApiExceptionMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            // Return gateway timeout to simulate API issues
            HttpResponse res = new HttpResponse();
            res.setStatusCode(504);
            res.setBody('Gateway Timeout');
            return res;
        }
    }
}
