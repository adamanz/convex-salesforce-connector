import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';

// OAuth Service methods
import getAuthorizationUrl from '@salesforce/apex/ConvexOAuthService.getAuthorizationUrl';
import getActiveConnection from '@salesforce/apex/ConvexOAuthService.getActiveConnection';
import isConnectedApex from '@salesforce/apex/ConvexOAuthService.isConnected';
import disconnect from '@salesforce/apex/ConvexOAuthService.disconnect';
import configureWebhook from '@salesforce/apex/ConvexOAuthService.configureWebhook';

// CDC Service methods
import testConnectionApex from '@salesforce/apex/ConvexCDCService.testConnection';

export default class ConvexSetupWizard extends NavigationMixin(LightningElement) {
    @track currentStep = '1';
    @track webhookUrl = '';
    @track webhookSecret = '';
    @track isEnabled = true;
    @track isLoading = false;
    @track testComplete = false;
    @track testSuccess = false;
    @track testError = '';

    // OAuth state
    @track isConnected = false;
    @track connectionTeam = '';
    @track connectionProject = '';
    @track connectionDate = '';
    @track configurationComplete = false;
    @track configurationStatus = '';

    // Wire current page reference to detect OAuth callback
    @wire(CurrentPageReference)
    handlePageReference(pageRef) {
        if (pageRef && pageRef.state) {
            // Check if returning from OAuth
            if (pageRef.state.oauth === 'success') {
                this.currentStep = '3'; // Go to configure step
                this.loadConnection();
                this.showToast('Success', 'Successfully connected to Convex!', 'success');
            }
        }
    }

    // Load connection on component init
    connectedCallback() {
        this.loadConnection();
    }

    // Load active connection from Salesforce
    async loadConnection() {
        try {
            const connection = await getActiveConnection();
            if (connection) {
                this.isConnected = true;
                this.connectionTeam = connection.Team_Name__c || 'Unknown';
                this.connectionProject = connection.Project_Name__c || '';
                this.connectionDate = connection.Connected_At__c
                    ? new Date(connection.Connected_At__c).toLocaleDateString()
                    : '';
                this.webhookUrl = connection.Deployment_URL__c
                    ? connection.Deployment_URL__c + '/webhooks/salesforce/cdc'
                    : '';
            } else {
                this.isConnected = false;
            }
        } catch (error) {
            console.error('Error loading connection:', error);
        }
    }

    // Step getters
    get isStep1() { return this.currentStep === '1'; }
    get isStep2() { return this.currentStep === '2'; }
    get isStep3() { return this.currentStep === '3'; }
    get isStep4() { return this.currentStep === '4'; }
    get isStep5() { return this.currentStep === '5'; }

    get isFirstStep() { return this.currentStep === '1'; }
    get isLastStep() { return this.currentStep === '5'; }

    get nextButtonLabel() {
        if (this.currentStep === '2' && !this.isConnected) return 'Skip (Manual Setup)';
        if (this.currentStep === '3') return 'Continue';
        if (this.currentStep === '5') return 'Finish';
        return 'Next';
    }

    get isNextDisabled() {
        if (this.currentStep === '2') {
            // Can proceed if connected, or allow manual setup
            return false;
        }
        if (this.currentStep === '3') {
            // Should have configuration complete or manual config
            return !this.configurationComplete && !this.webhookUrl;
        }
        return false;
    }

    // ============================================================================
    // OAuth Flow Methods
    // ============================================================================

    async initiateOAuth() {
        this.isLoading = true;
        try {
            const authUrl = await getAuthorizationUrl({ scope: 'project' });
            // Redirect to Convex OAuth
            window.location.href = authUrl;
        } catch (error) {
            this.showToast('Error', 'Failed to initiate OAuth: ' + this.getErrorMessage(error), 'error');
            this.isLoading = false;
        }
    }

    async handleDisconnect() {
        this.isLoading = true;
        try {
            await disconnect();
            this.isConnected = false;
            this.connectionTeam = '';
            this.connectionProject = '';
            this.connectionDate = '';
            this.webhookUrl = '';
            this.configurationComplete = false;
            this.showToast('Disconnected', 'Convex connection has been removed.', 'info');
        } catch (error) {
            this.showToast('Error', 'Failed to disconnect: ' + this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ============================================================================
    // Configuration Methods
    // ============================================================================

    async autoConfigureWebhook() {
        this.isLoading = true;
        this.configurationStatus = 'Configuring webhook...';

        try {
            const result = await configureWebhook();

            if (result.success) {
                this.webhookUrl = result.webhookUrl;
                this.webhookSecret = result.webhookSecret;
                this.configurationComplete = true;
                this.configurationStatus = '';

                // Auto-test the connection
                await this.testConnection();

                this.showToast('Success', 'Webhook configured successfully!', 'success');
            } else {
                this.showToast('Error', result.error || 'Configuration failed', 'error');
                this.configurationStatus = '';
            }
        } catch (error) {
            this.showToast('Error', 'Configuration failed: ' + this.getErrorMessage(error), 'error');
            this.configurationStatus = '';
        } finally {
            this.isLoading = false;
        }
    }

    async testConnection() {
        this.isLoading = true;
        this.testComplete = false;

        try {
            const result = await testConnectionApex();

            this.testComplete = true;
            if (result.success) {
                this.testSuccess = true;
                this.showToast('Success', 'Connection to Convex is working!', 'success');
            } else {
                this.testSuccess = false;
                this.testError = result.error || 'Unknown error occurred';
                this.showToast('Warning', 'Connection test failed: ' + this.testError, 'warning');
            }
        } catch (error) {
            this.testComplete = true;
            this.testSuccess = false;
            this.testError = this.getErrorMessage(error);
            this.showToast('Error', this.testError, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ============================================================================
    // Manual Configuration Methods
    // ============================================================================

    handleWebhookUrlChange(event) {
        this.webhookUrl = event.target.value;
    }

    handleWebhookSecretChange(event) {
        this.webhookSecret = event.target.value;
    }

    handleEnabledChange(event) {
        this.isEnabled = event.target.checked;
    }

    generateSecret() {
        // Generate a random 32-character hex string
        const array = new Uint8Array(16);
        crypto.getRandomValues(array);
        this.webhookSecret = Array.from(array, byte => byte.toString(16).padStart(2, '0')).join('');
        this.showToast('Secret Generated', 'A new webhook secret has been generated.', 'success');
    }

    async saveManualConfig() {
        if (!this.webhookUrl) {
            this.showToast('Error', 'Please enter a webhook URL', 'error');
            return;
        }

        this.configurationComplete = true;
        this.showToast(
            'Configuration Saved',
            'Manual settings saved. Remember to add the webhook secret to Convex.',
            'success'
        );
    }

    // ============================================================================
    // Navigation Methods
    // ============================================================================

    openCDCSetup() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/lightning/setup/CdcObjectEnablement/home'
            }
        });
    }

    openDocs() {
        window.open('https://github.com/adamanz/convex-salesforce-connector', '_blank');
    }

    openConvexDashboard() {
        window.open('https://dashboard.convex.dev', '_blank');
    }

    previousStep() {
        const step = parseInt(this.currentStep, 10);
        if (step > 1) {
            this.currentStep = String(step - 1);
        }
    }

    async nextStep() {
        const step = parseInt(this.currentStep, 10);

        if (step < 5) {
            this.currentStep = String(step + 1);
        }

        // Reset states when entering certain steps
        if (this.currentStep === '3') {
            this.testComplete = false;
            this.testSuccess = false;
        }
    }

    resetWizard() {
        this.currentStep = '1';
        this.webhookUrl = '';
        this.webhookSecret = '';
        this.isEnabled = true;
        this.testComplete = false;
        this.testSuccess = false;
        this.testError = '';
        this.configurationComplete = false;
        this.loadConnection();
    }

    // ============================================================================
    // Utility Methods
    // ============================================================================

    getErrorMessage(error) {
        if (typeof error === 'string') return error;
        if (error.body && error.body.message) return error.body.message;
        if (error.message) return error.message;
        return 'Unknown error';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }
}
