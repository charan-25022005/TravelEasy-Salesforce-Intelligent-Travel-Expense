import { LightningElement, api, wire, track } from 'lwc';
import getTripWalletDetails from '@salesforce/apex/TripWalletController.getTripWalletDetails';
import getExpenseItems from '@salesforce/apex/TripWalletController.getExpenseItems';
import submitQuickExpense from '@salesforce/apex/TripWalletController.submitQuickExpense';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

export default class TripWallet extends LightningElement {
    @api recordId;

    @track walletData;
    @track expenseItems = [];
    @track isLoading = false;
    @track showModal = false;

    // Form inputs
    @track formCategory = 'Meals & Food';
    @track formAmount;
    @track formExpenseDate;
    @track formVendor = '';
    @track formDescription = '';
    @track formReceiptAttached = true;

    wiredWalletResult;
    wiredItemsResult;

    categoryOptions = [
        { label: 'Meals & Food', value: 'Meals & Food' },
        { label: 'Hotel / Lodging', value: 'Hotel / Lodging' },
        { label: 'Airfare', value: 'Airfare' },
        { label: 'Ground Transportation / Taxi', value: 'Ground Transportation / Taxi' },
        { label: 'Client Entertainment', value: 'Client Entertainment' },
        { label: 'Fuel', value: 'Fuel' },
        { label: 'Incidentals / Miscellaneous', value: 'Incidentals / Miscellaneous' }
    ];

    connectedCallback() {
        const today = new Date();
        this.formExpenseDate = today.toISOString().split('T')[0];
    }

    @wire(getTripWalletDetails, { travelRequestId: '$recordId' })
    wiredWallet(result) {
        this.wiredWalletResult = result;
        if (result.data) {
            this.walletData = result.data;
        } else if (result.error) {
            this.showToast('Error', result.error.body ? result.error.body.message : 'Failed to load wallet', 'error');
        }
    }

    @wire(getExpenseItems, { travelRequestId: '$recordId' })
    wiredItems(result) {
        this.wiredItemsResult = result;
        if (result.data) {
            this.expenseItems = result.data.map(item => ({
                ...item,
                validationBadgeClass: item.validationStatus === 'Passed' 
                    ? 'slds-badge slds-theme_success' 
                    : (item.validationStatus === 'Exception Detected' 
                        ? 'slds-badge slds-theme_error' 
                        : 'slds-badge')
            }));
        } else if (result.error) {
            this.showToast('Error', result.error.body ? result.error.body.message : 'Failed to load expenses', 'error');
        }
    }

    get hasExceptions() {
        return this.walletData && this.walletData.openExceptionCount > 0;
    }

    get progressBarVariant() {
        if (!this.walletData) return 'base';
        if (this.walletData.utilizationPercent > 100) return 'error';
        if (this.walletData.utilizationPercent > 80) return 'warning';
        return 'success';
    }

    handleOpenModal() {
        this.showModal = true;
    }

    handleCloseModal() {
        this.showModal = false;
    }

    handleFormChange(event) {
        const field = event.target.name;
        if (field === 'category') this.formCategory = event.target.value;
        else if (field === 'amount') this.formAmount = parseFloat(event.target.value);
        else if (field === 'expenseDate') this.formExpenseDate = event.target.value;
        else if (field === 'vendor') this.formVendor = event.target.value;
        else if (field === 'description') this.formDescription = event.target.value;
        else if (field === 'receiptAttached') this.formReceiptAttached = event.target.checked;
    }

    async handleSubmitQuickExpense() {
        if (!this.formAmount || this.formAmount <= 0) {
            this.showToast('Validation Error', 'Amount must be greater than zero.', 'error');
            return;
        }

        this.isLoading = true;
        try {
            await submitQuickExpense({
                travelRequestId: this.recordId,
                category: this.formCategory,
                amount: this.formAmount,
                expenseDate: this.formExpenseDate,
                vendor: this.formVendor,
                description: this.formDescription,
                receiptAttached: this.formReceiptAttached
            });

            this.showToast('Success', 'Expense recorded and evaluated by Smart Expense Control.', 'success');
            this.showModal = false;
            this.handleResetForm();
            await this.handleRefresh();
        } catch (error) {
            this.showToast('Error', error.body ? error.body.message : error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleResetForm() {
        this.formAmount = null;
        this.formVendor = '';
        this.formDescription = '';
        this.formReceiptAttached = true;
    }

    async handleRefresh() {
        this.isLoading = true;
        try {
            await Promise.all([
                refreshApex(this.wiredWalletResult),
                refreshApex(this.wiredItemsResult)
            ]);
        } finally {
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
