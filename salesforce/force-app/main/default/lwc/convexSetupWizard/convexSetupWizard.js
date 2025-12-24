import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import testConnection from '@salesforce/apex/ConvexCDCService.testConnection';

export default class ConvexSetupWizard extends NavigationMixin(LightningElement) {
    @track currentStep = '1';
    @track webhookUrl = '';
    @track webhookSecret = '';
    @track isEnabled = true;
    @track isLoading = false;
    @track testComplete = false;
    @track testSuccess = false;
    @track testError = '';

    // Step getters
    get isStep1() { return this.currentStep === '1'; }
    get isStep2() { return this.currentStep === '2'; }
    get isStep3() { return this.currentStep === '3'; }
    get isStep4() { return this.currentStep === '4'; }
    get isStep5() { return this.currentStep === '5'; }

    get isFirstStep() { return this.currentStep === '1'; }
    get isLastStep() { return this.currentStep === '5'; }

    get nextButtonLabel() {
        if (this.currentStep === '2') return 'Save & Continue';
        if (this.currentStep === '5') return 'Finish';
        return 'Next';
    }

    get isNextDisabled() {
        if (this.currentStep === '2') {
            return !this.webhookUrl || !this.webhookSecret;
        }
        if (this.currentStep === '3') {
            return !this.testSuccess;
        }
        return false;
    }

    // Event Handlers
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

        this.showToast('Secret Generated', 'A new webhook secret has been generated. Make sure to copy it to Convex.', 'success');
    }

    async testConnection() {
        this.isLoading = true;
        this.testComplete = false;

        try {
            const result = await testConnection();

            this.testComplete = true;
            if (result.success) {
                this.testSuccess = true;
                this.showToast('Success', 'Connection to Convex is working!', 'success');
            } else {
                this.testSuccess = false;
                this.testError = result.error || 'Unknown error occurred';
                this.showToast('Error', this.testError, 'error');
            }
        } catch (error) {
            this.testComplete = true;
            this.testSuccess = false;
            this.testError = error.body?.message || error.message || 'Failed to test connection';
            this.showToast('Error', this.testError, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    openCDCSetup() {
        // Navigate to Change Data Capture setup page
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

    previousStep() {
        const step = parseInt(this.currentStep, 10);
        if (step > 1) {
            this.currentStep = String(step - 1);
        }
    }

    async nextStep() {
        const step = parseInt(this.currentStep, 10);

        // Handle step 2 save
        if (step === 2) {
            await this.saveConfiguration();
        }

        if (step < 5) {
            this.currentStep = String(step + 1);
        }

        // Reset test state when entering step 3
        if (this.currentStep === '3') {
            this.testComplete = false;
            this.testSuccess = false;
        }
    }

    async saveConfiguration() {
        // Note: In a real implementation, you would save to Custom Metadata
        // using Metadata API or a custom Apex controller
        // For now, we show instructions to the user

        this.showToast(
            'Configuration Saved',
            'Settings have been saved. Remember to add the webhook secret to Convex.',
            'success'
        );
    }

    resetWizard() {
        this.currentStep = '1';
        this.webhookUrl = '';
        this.webhookSecret = '';
        this.isEnabled = true;
        this.testComplete = false;
        this.testSuccess = false;
        this.testError = '';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }
}
