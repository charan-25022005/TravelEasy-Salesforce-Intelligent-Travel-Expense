/**
 * @description Trigger Handler for Reimbursement__c.
 * Architecture: Manages reimbursement lifecycle, employee assignments,
 * and parent expense report status synchronization.
 */
public with sharing class ReimbursementTriggerHandler {

    public static void handleBeforeInsert(List<Reimbursement__c> newRecords) {
        for (Reimbursement__c rmb : newRecords) {
            if (rmb.Employee__c == null) {
                rmb.Employee__c = UserInfo.getUserId();
            }
            if (String.isBlank(rmb.Reimbursement_Status__c)) {
                rmb.Reimbursement_Status__c = 'Pending';
            }
            if (rmb.Processing_Date__c == null) {
                rmb.Processing_Date__c = Date.today();
            }
        }
    }

    public static void handleBeforeUpdate(List<Reimbursement__c> newRecords, Map<Id, Reimbursement__c> oldMap) {
        for (Reimbursement__c rmb : newRecords) {
            Reimbursement__c old = oldMap.get(rmb.Id);
            if (rmb.Reimbursement_Status__c == 'Completed' && old.Reimbursement_Status__c != 'Completed') {
                if (rmb.Completion_Date__c == null) {
                    rmb.Completion_Date__c = Date.today();
                }
            }
        }
    }

    public static void handleAfterInsert(List<Reimbursement__c> newRecords) {
        // Post-insert handling
    }

    public static void handleAfterUpdate(List<Reimbursement__c> newRecords, Map<Id, Reimbursement__c> oldMap) {
        Set<Id> completedReportIds = new Set<Id>();
        for (Reimbursement__c rmb : newRecords) {
            Reimbursement__c old = oldMap.get(rmb.Id);
            if (rmb.Reimbursement_Status__c == 'Completed' && old.Reimbursement_Status__c != 'Completed') {
                if (rmb.Expense_Report__c != null) {
                    completedReportIds.add(rmb.Expense_Report__c);
                }
            }
        }

        if (!completedReportIds.isEmpty()) {
            List<Expense_Report__c> reportsToUpdate = new List<Expense_Report__c>();
            for (Id repId : completedReportIds) {
                reportsToUpdate.add(new Expense_Report__c(
                    Id = repId,
                    Reimbursement_Status__c = 'Reimbursed',
                    Status__c = 'Reimbursed'
                ));
            }
            if (Schema.sObjectType.Expense_Report__c.isUpdateable()) {
                update reportsToUpdate;
            }
        }
    }
}
