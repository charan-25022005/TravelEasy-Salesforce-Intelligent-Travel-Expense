/**
 * @description Batch Apex for enterprise-scale Travel & Expense Reconciliation.
 * Processes high volume expense records, detects cross-report duplicates,
 * validates policy alignment, tracks unresolved exceptions, and writes
 * reconciliation audit summaries to Integration_Log__c.
 */
public with sharing class TravelExpenseReconciliationBatch implements Database.Batchable<sObject>, Database.Stateful {

    public Integer totalProcessedCount = 0;
    public Integer exceptionsFlaggedCount = 0;
    public Decimal totalReconciledAmount = 0.00;

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Expense_Report__c, Expense_Report__r.Employee__c,
                   Expense_Category__c, Amount__c, Expense_Date__c, Vendor__c,
                   Validation_Status__c, Policy_Result__c, Receipt_Attached__c,
                   Receipt_Document_Id__c, Is_Duplicate_Flag__c
            FROM Expense_Item__c
            WHERE Validation_Status__c != 'Passed' OR Policy_Result__c = 'Verification Required' OR Is_Duplicate_Flag__c = true
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Expense_Item__c> scope) {
        if (scope == null || scope.isEmpty()) {
            return;
        }

        totalProcessedCount += scope.size();
        for (Expense_Item__c item : scope) {
            if (item.Amount__c != null) {
                totalReconciledAmount += item.Amount__c;
            }
        }

        // Re-evaluate items using Smart Expense Control Service
        SmartExpenseControlService.evaluateExpenseItems(scope);

        if (Schema.sObjectType.Expense_Item__c.isUpdateable()) {
            update scope;
        }

        for (Expense_Item__c itm : scope) {
            if (itm.Validation_Status__c == 'Exception Detected') {
                exceptionsFlaggedCount++;
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        String summaryPayload = JSON.serialize(new Map<String, Object>{
            'batchJobId' => bc != null ? bc.getJobId() : 'MANUAL',
            'totalProcessedRecords' => totalProcessedCount,
            'exceptionsIdentified' => exceptionsFlaggedCount,
            'totalReconciledAmount' => totalReconciledAmount,
            'completionTimestamp' => Datetime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'')
        });

        IntegrationLogService.log(
            'TravelExpenseReconciliationBatch',
            'InternalBatchJob://Reconciliation',
            'Query: Unreconciled Expense Items',
            summaryPayload,
            200,
            'Success',
            null,
            null
        );
    }
}
