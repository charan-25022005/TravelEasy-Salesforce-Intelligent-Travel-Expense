/**
 * @description Queueable Apex executing asynchronous finance disbursement processing.
 * Dispatches simulated ERP / payment gateway transaction, updates reimbursement status,
 * populates bank transaction ID, and writes structured audit logs to Integration_Log__c.
 */
public with sharing class ProcessReimbursementQueueable implements Queueable, Database.AllowsCallouts {

    private List<Id> reimbursementIds;

    public ProcessReimbursementQueueable(List<Id> ids) {
        this.reimbursementIds = ids;
    }

    public void execute(QueueableContext context) {
        if (reimbursementIds == null || reimbursementIds.isEmpty()) {
            return;
        }

        List<Reimbursement__c> reimbursements = [
            SELECT Id, Approved_Amount__c, Employee__c, Employee__r.Name, Employee__r.Email,
                   Expense_Report__c, Reimbursement_Status__c, Payment_Method__c
            FROM Reimbursement__c
            WHERE Id IN :reimbursementIds AND Reimbursement_Status__c = 'Pending'
        ];

        List<Reimbursement__c> toUpdate = new List<Reimbursement__c>();
        Set<Id> reportIdsToReimburse = new Set<Id>();

        for (Reimbursement__c rmb : reimbursements) {
            String transactionRef = 'PAY-' + System.currentTimeMillis() + '-' + Math.round(Math.random() * 8999 + 1000);
            String bankTxnId = 'UTR' + String.valueOf(Math.abs(Crypto.getRandomInteger())).left(9);

            // Simulated external JSON payload
            String requestPayload = JSON.serialize(new Map<String, Object>{
                'reimbursementId' => rmb.Id,
                'beneficiary' => rmb.Employee__r.Name,
                'email' => rmb.Employee__r.Email,
                'amount' => rmb.Approved_Amount__c,
                'currency' => 'INR',
                'method' => rmb.Payment_Method__c
            });

            String responsePayload = JSON.serialize(new Map<String, Object>{
                'status' => 'COMPLETED',
                'paymentReference' => transactionRef,
                'bankTransactionId' => bankTxnId,
                'settlementTimestamp' => Datetime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'')
            });

            // Log integration execution
            IntegrationLogService.log(
                'FinanceDisbursementGateway',
                'callout:Finance_ERP_Endpoint/api/v1/disburse',
                requestPayload,
                responsePayload,
                200,
                'Success',
                null,
                rmb.Id
            );

            rmb.Reimbursement_Status__c = 'Completed';
            rmb.Payment_Reference__c = transactionRef;
            rmb.Bank_Transaction_Id__c = bankTxnId;
            rmb.Completion_Date__c = Date.today();
            rmb.Comments__c = 'Automated disbursement processed successfully via Queueable gateway.';
            toUpdate.add(rmb);

            if (rmb.Expense_Report__c != null) {
                reportIdsToReimburse.add(rmb.Expense_Report__c);
            }
        }

        if (!toUpdate.isEmpty() && Schema.sObjectType.Reimbursement__c.isUpdateable()) {
            update toUpdate;
        }

        // Update Expense Reports to Reimbursed
        if (!reportIdsToReimburse.isEmpty()) {
            List<Expense_Report__c> reportsToUpdate = new List<Expense_Report__c>();
            for (Id repId : reportIdsToReimburse) {
                reportsToUpdate.add(new Expense_Report__c(
                    Id = repId,
                    Status__c = 'Reimbursed',
                    Reimbursement_Status__c = 'Reimbursed'
                ));
            }
            if (Schema.sObjectType.Expense_Report__c.isUpdateable()) {
                update reportsToUpdate;
            }
        }
    }
}
