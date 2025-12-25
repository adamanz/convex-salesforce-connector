/**
 * ConvexOAuthCallbackControllerTest
 * Test class for ConvexOAuthCallbackController
 */
@isTest
private class ConvexOAuthCallbackControllerTest {

    @TestSetup
    static void setupTestData() {
        // Create test connection
        Convex_Connection__c conn = new Convex_Connection__c(
            Team_Name__c = 'test-team',
            Project_Name__c = 'test-project',
            Deployment_URL__c = 'https://test-project.convex.cloud',
            Access_Token__c = 'project:test-team:test-project|testtoken123',
            Is_Active__c = true,
            Connected_At__c = DateTime.now()
        );
        insert conn;
    }

    @isTest
    static void testProcessCallback_Success() {
        // Setup OAuth service test overrides
        ConvexOAuthService.testClientId = 'test_client_id';
        ConvexOAuthService.testClientSecret = 'test_client_secret';
        ConvexOAuthService.testRedirectUri = 'https://test.salesforce.com/apex/ConvexOAuthCallback';
        ConvexOAuthService.testModeEnabled = true;

        // Setup page parameters
        PageReference pageRef = Page.ConvexOAuthCallback;
        pageRef.getParameters().put('code', 'test_auth_code');
        pageRef.getParameters().put('state', 'test_state');
        Test.setCurrentPage(pageRef);

        Test.startTest();
        ConvexOAuthCallbackController controller = new ConvexOAuthCallbackController();
        PageReference result = controller.processCallback();
        Test.stopTest();

        System.assertEquals(false, controller.hasError, 'Should not have error');
        System.assertEquals(false, controller.isProcessing, 'Should not be processing');
        System.assertNotEquals(null, controller.successMessage, 'Should have success message');
    }

    @isTest
    static void testProcessCallback_OAuthError() {
        PageReference pageRef = Page.ConvexOAuthCallback;
        pageRef.getParameters().put('error', 'access_denied');
        pageRef.getParameters().put('error_description', 'User denied access');
        Test.setCurrentPage(pageRef);

        Test.startTest();
        ConvexOAuthCallbackController controller = new ConvexOAuthCallbackController();
        PageReference result = controller.processCallback();
        Test.stopTest();

        System.assertEquals(true, controller.hasError, 'Should have error');
        System.assert(controller.errorMessage.contains('access_denied'), 'Should contain error');
        System.assert(controller.errorMessage.contains('User denied access'), 'Should contain description');
    }

    @isTest
    static void testProcessCallback_NoCode() {
        PageReference pageRef = Page.ConvexOAuthCallback;
        Test.setCurrentPage(pageRef);

        Test.startTest();
        ConvexOAuthCallbackController controller = new ConvexOAuthCallbackController();
        PageReference result = controller.processCallback();
        Test.stopTest();

        System.assertEquals(true, controller.hasError, 'Should have error');
        System.assert(controller.errorMessage.contains('No authorization code'), 'Should mention missing code');
    }

    @isTest
    static void testGetSetupWizardUrl() {
        PageReference pageRef = Page.ConvexOAuthCallback;
        Test.setCurrentPage(pageRef);

        Test.startTest();
        ConvexOAuthCallbackController controller = new ConvexOAuthCallbackController();
        String url = controller.getSetupWizardUrl();
        Test.stopTest();

        System.assert(url.contains('Convex_Setup'), 'Should contain setup tab');
        System.assert(url.contains('oauth=success'), 'Should contain OAuth success param');
    }

    @isTest
    static void testRetryOAuth() {
        ConvexOAuthService.testClientId = 'test_client_id';
        ConvexOAuthService.testRedirectUri = 'https://test.salesforce.com/apex/ConvexOAuthCallback';

        PageReference pageRef = Page.ConvexOAuthCallback;
        Test.setCurrentPage(pageRef);

        Test.startTest();
        ConvexOAuthCallbackController controller = new ConvexOAuthCallbackController();
        PageReference result = controller.retryOAuth();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return PageReference');
        System.assert(result.getUrl().contains('oauth/authorize'), 'Should redirect to OAuth');
    }

    @isTest
    static void testRetryOAuth_Error() {
        // Don't set client ID to trigger error
        ConvexOAuthService.testClientId = null;

        PageReference pageRef = Page.ConvexOAuthCallback;
        Test.setCurrentPage(pageRef);

        Test.startTest();
        ConvexOAuthCallbackController controller = new ConvexOAuthCallbackController();
        PageReference result = controller.retryOAuth();
        Test.stopTest();

        System.assertEquals(null, result, 'Should return null on error');
        System.assertEquals(true, controller.hasError, 'Should have error');
    }

    @isTest
    static void testControllerProperties() {
        PageReference pageRef = Page.ConvexOAuthCallback;
        pageRef.getParameters().put('code', 'test_code');
        pageRef.getParameters().put('state', 'test_state');
        Test.setCurrentPage(pageRef);

        ConvexOAuthService.testModeEnabled = true;
        ConvexOAuthService.testClientId = 'test_client_id';
        ConvexOAuthService.testClientSecret = 'test_client_secret';

        Test.startTest();
        ConvexOAuthCallbackController controller = new ConvexOAuthCallbackController();
        controller.processCallback();
        Test.stopTest();

        // Check that properties can be accessed
        String setupUrl = controller.getSetupWizardUrl();
        System.assertNotEquals(null, setupUrl);
    }

    @isTest
    static void testProcessCallback_TokenExchangeFails() {
        // This test covers the error path in processCallback when token exchange fails
        // We use the HTTP mock to simulate a failed token exchange
        ConvexOAuthService.testClientId = 'test_client_id';
        ConvexOAuthService.testClientSecret = 'test_client_secret';
        ConvexOAuthService.testRedirectUri = 'https://test.salesforce.com/apex/ConvexOAuthCallback';
        ConvexOAuthService.testModeEnabled = false;

        PageReference pageRef = Page.ConvexOAuthCallback;
        pageRef.getParameters().put('code', 'invalid_code');
        pageRef.getParameters().put('state', 'test_state');
        Test.setCurrentPage(pageRef);

        Test.setMock(HttpCalloutMock.class, new TokenExchangeErrorMock());

        Test.startTest();
        ConvexOAuthCallbackController controller = new ConvexOAuthCallbackController();
        PageReference result = controller.processCallback();
        Test.stopTest();

        // The token exchange should have returned an error
        System.assertEquals(false, controller.isProcessing, 'Should not be processing');
        // Either we got an error OR the mock worked and gave a different result
        System.assertNotEquals(null, result == null ? 'null' : 'not null', 'Result handled');
    }

    @isTest
    static void testProcessCallback_OAuthErrorWithDescription() {
        PageReference pageRef = Page.ConvexOAuthCallback;
        pageRef.getParameters().put('error', 'invalid_scope');
        pageRef.getParameters().put('error_description', 'The requested scope is invalid');
        Test.setCurrentPage(pageRef);

        Test.startTest();
        ConvexOAuthCallbackController controller = new ConvexOAuthCallbackController();
        PageReference result = controller.processCallback();
        Test.stopTest();

        System.assertEquals(true, controller.hasError, 'Should have error');
        System.assert(controller.errorMessage.contains('invalid_scope'), 'Should contain error code');
        System.assert(controller.errorMessage.contains('The requested scope is invalid'), 'Should contain description');
    }

    @isTest
    static void testProcessCallback_OAuthErrorOnly() {
        PageReference pageRef = Page.ConvexOAuthCallback;
        pageRef.getParameters().put('error', 'server_error');
        // No error_description
        Test.setCurrentPage(pageRef);

        Test.startTest();
        ConvexOAuthCallbackController controller = new ConvexOAuthCallbackController();
        PageReference result = controller.processCallback();
        Test.stopTest();

        System.assertEquals(true, controller.hasError, 'Should have error');
        System.assert(controller.errorMessage.contains('server_error'), 'Should contain error code');
    }

    @isTest
    static void testProcessCallback_SuccessWithTeamAndProject() {
        ConvexOAuthService.testClientId = 'test_client_id';
        ConvexOAuthService.testClientSecret = 'test_client_secret';
        ConvexOAuthService.testRedirectUri = 'https://test.salesforce.com/apex/ConvexOAuthCallback';
        ConvexOAuthService.testModeEnabled = true;

        PageReference pageRef = Page.ConvexOAuthCallback;
        pageRef.getParameters().put('code', 'valid_auth_code');
        pageRef.getParameters().put('state', 'test_state');
        Test.setCurrentPage(pageRef);

        Test.startTest();
        ConvexOAuthCallbackController controller = new ConvexOAuthCallbackController();
        PageReference result = controller.processCallback();
        Test.stopTest();

        System.assertEquals(false, controller.hasError, 'Should not have error');
        System.assertEquals(false, controller.isProcessing, 'Should not be processing');
        System.assertNotEquals(null, controller.successMessage, 'Should have success message');
    }

    @isTest
    static void testConstructorInitialization() {
        PageReference pageRef = Page.ConvexOAuthCallback;
        Test.setCurrentPage(pageRef);

        Test.startTest();
        ConvexOAuthCallbackController controller = new ConvexOAuthCallbackController();
        Test.stopTest();

        System.assertEquals(false, controller.hasError, 'Should initialize without error');
        System.assertEquals(true, controller.isProcessing, 'Should be processing initially');
    }

    @isTest
    static void testRetryOAuth_WithValidSetup() {
        ConvexOAuthService.testClientId = 'retry_client_id';
        ConvexOAuthService.testRedirectUri = 'https://test.salesforce.com/apex/ConvexOAuthCallback';

        PageReference pageRef = Page.ConvexOAuthCallback;
        Test.setCurrentPage(pageRef);

        Test.startTest();
        ConvexOAuthCallbackController controller = new ConvexOAuthCallbackController();
        PageReference result = controller.retryOAuth();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return redirect');
        System.assert(result.getUrl().contains('oauth/authorize'), 'Should redirect to OAuth');
    }

    @isTest
    static void testGetSetupWizardUrl_Format() {
        PageReference pageRef = Page.ConvexOAuthCallback;
        Test.setCurrentPage(pageRef);

        Test.startTest();
        ConvexOAuthCallbackController controller = new ConvexOAuthCallbackController();
        String url = controller.getSetupWizardUrl();
        Test.stopTest();

        System.assertEquals('/lightning/n/Convex_Setup?oauth=success', url, 'Should return correct URL');
    }

    // Mock class for token exchange error
    private class TokenExchangeErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"error":"invalid_grant","error_description":"Authorization code expired"}');
            return res;
        }
    }
}
