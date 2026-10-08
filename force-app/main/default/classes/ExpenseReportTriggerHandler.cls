/**
 * @description Trigger Handler for Expense_Report__c.
 * Architecture: Manages expense report lifecycle, validation status,
 * and reimbursement initiation upon approval.
 */
public with sharing class ExpenseReportTriggerHandler {

    public static void handleBeforeInsert(List<Expense_Report__c> newRecords) {
        for (Expense_Report__c er : newRecords) {
            if (er.Employee__c == null) {
                er.Employee__c = UserInfo.getUserId();
            }
            if (er.Report_Date__c == null) {
                er.Report_Date__c = Date.today();
            }
            if (String.isBlank(er.Status__c)) {
                er.Status__c = 'Draft';
            }
            if (String.isBlank(er.Validation_Status__c)) {
                er.Validation_Status__c = 'Pending Validation';
            }
            if (String.isBlank(er.Approval_Status__c)) {
                er.Approval_Status__c = 'Pending';
            }
            if (String.isBlank(er.Reimbursement_Status__c)) {
                er.Reimbursement_Status__c = 'Not Applicable';
            }
        }
    }

    public static void handleBeforeUpdate(List<Expense_Report__c> newRecords, Map<Id, Expense_Report__c> oldMap) {
        for (Expense_Report__c er : newRecords) {
            Expense_Report__c old = oldMap.get(er.Id);
            // Synchronize status when approval status changes
            if (er.Approval_Status__c != old.Approval_Status__c) {
                if (er.Approval_Status__c == 'Approved') {
                    er.Status__c = 'Approved';
                    er.Reimbursement_Status__c = 'Pending Reimbursement';
                } else if (er.Approval_Status__c == 'Rejected') {
                    er.Status__c = 'Rejected';
                }
            }
        }
    }

    public static void handleAfterInsert(List<Expense_Report__c> newRecords) {
        // Post-insert handling
    }

    public static void handleAfterUpdate(List<Expense_Report__c> newRecords, Map<Id, Expense_Report__c> oldMap) {
        List<Expense_Report__c> newlyApproved = new List<Expense_Report__c>();
        for (Expense_Report__c er : newRecords) {
            Expense_Report__c old = oldMap.get(er.Id);
            if ((er.Status__c == 'Approved' && old.Status__c != 'Approved') ||
                (er.Approval_Status__c == 'Approved' && old.Approval_Status__c != 'Approved')) {
                newlyApproved.add(er);
            }
        }

        if (!newlyApproved.isEmpty()) {
            ReimbursementService.generateReimbursementsForApprovedReports(newlyApproved);
        }
    }
}
