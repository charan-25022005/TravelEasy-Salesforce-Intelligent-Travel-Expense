/**
 * @description Trigger Handler for Expense_Item__c.
 * Architecture: Automatically calculates reimbursable amounts based on payment mode,
 * sets Smart Expense Control validation fields before insert/update,
 * and generates exception records after insert/update.
 */
public with sharing class ExpenseItemTriggerHandler {

    public static void handleBeforeInsert(List<Expense_Item__c> newRecords) {
        for (Expense_Item__c item : newRecords) {
            if (item.Expense_Date__c == null) {
                item.Expense_Date__c = Date.today();
            }
            if (String.isBlank(item.Paid_By__c)) {
                item.Paid_By__c = 'Personal Cash / Card';
            }
            if (item.Participants_Count__c == null || item.Participants_Count__c < 1) {
                item.Participants_Count__c = 1;
            }
            calculateReimbursableAmount(item);
        }
        SmartExpenseControlService.evaluateExpenseItemsBefore(newRecords);
    }

    public static void handleBeforeUpdate(List<Expense_Item__c> newRecords, Map<Id, Expense_Item__c> oldMap) {
        for (Expense_Item__c item : newRecords) {
            Expense_Item__c old = oldMap.get(item.Id);
            if (item.Amount__c != old.Amount__c || item.Paid_By__c != old.Paid_By__c) {
                calculateReimbursableAmount(item);
            }
        }
        SmartExpenseControlService.evaluateExpenseItemsBefore(newRecords);
    }

    public static void handleAfterInsert(List<Expense_Item__c> newRecords) {
        SmartExpenseControlService.createExceptionsAfter(newRecords);
    }

    public static void handleAfterUpdate(List<Expense_Item__c> newRecords, Map<Id, Expense_Item__c> oldMap) {
        SmartExpenseControlService.createExceptionsAfter(newRecords);
    }

    private static void calculateReimbursableAmount(Expense_Item__c item) {
        if (item.Amount__c == null) {
            item.Reimbursable_Amount__c = 0;
            return;
        }
        if (item.Paid_By__c == 'Corporate Card') {
            item.Reimbursable_Amount__c = 0.00; // Directly billed to corporate card
        } else {
            item.Reimbursable_Amount__c = item.Amount__c; // Eligible for direct employee reimbursement
        }
    }
}
