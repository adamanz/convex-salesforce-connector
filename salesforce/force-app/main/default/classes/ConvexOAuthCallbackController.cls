/**
 * ConvexOAuthCallbackController
 * Handles the OAuth callback from Convex after user authorization.
 * Exchanges the authorization code for an access token and redirects
 * back to the setup wizard.
 */
public class ConvexOAuthCallbackController {

    public String errorMessage { get; set; }
    public String successMessage { get; set; }
    public Boolean hasError { get; set; }
    public Boolean isProcessing { get; set; }
    public String teamName { get; set; }
    public String projectName { get; set; }

    // URL parameters from OAuth callback
    private String code;
    private String state;
    private String error;
    private String errorDescription;

    public ConvexOAuthCallbackController() {
        hasError = false;
        isProcessing = true;

        // Get URL parameters
        code = ApexPages.currentPage().getParameters().get('code');
        state = ApexPages.currentPage().getParameters().get('state');
        error = ApexPages.currentPage().getParameters().get('error');
        errorDescription = ApexPages.currentPage().getParameters().get('error_description');
    }

    /**
     * Process the OAuth callback - called from page action
     */
    public PageReference processCallback() {
        try {
            // Check for OAuth error
            if (String.isNotBlank(error)) {
                hasError = true;
                errorMessage = 'Authorization failed: ' + error;
                if (String.isNotBlank(errorDescription)) {
                    errorMessage += ' - ' + errorDescription;
                }
                isProcessing = false;
                return null;
            }

            // Validate code is present
            if (String.isBlank(code)) {
                hasError = true;
                errorMessage = 'No authorization code received';
                isProcessing = false;
                return null;
            }

            // Exchange code for token
            Map<String, Object> result = ConvexOAuthService.exchangeCodeForToken(code, state);

            if ((Boolean) result.get('success')) {
                successMessage = 'Successfully connected to Convex!';
                teamName = (String) result.get('team_name');
                projectName = (String) result.get('project_name');
                isProcessing = false;

                // Redirect back to setup wizard after short delay (handled by page)
                return null;
            } else {
                hasError = true;
                errorMessage = (String) result.get('error');
                isProcessing = false;
                return null;
            }
        } catch (Exception e) {
            hasError = true;
            errorMessage = 'Error processing callback: ' + e.getMessage();
            isProcessing = false;
            return null;
        }
    }

    /**
     * Get the URL to return to the setup wizard
     */
    public String getSetupWizardUrl() {
        // Return to the Convex Setup tab/page
        return '/lightning/n/Convex_Setup?oauth=success';
    }

    /**
     * Action to retry the OAuth flow
     */
    public PageReference retryOAuth() {
        try {
            String authUrl = ConvexOAuthService.getAuthorizationUrl('project');
            return new PageReference(authUrl);
        } catch (Exception e) {
            hasError = true;
            errorMessage = 'Error initiating OAuth: ' + e.getMessage();
            return null;
        }
    }
}
