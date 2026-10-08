/**
 * @description Service layer managing the reimbursement lifecycle:
 * auto-creation upon expense report approval, eligibility verification,
 * and asynchronous finance payment queueing.
 */
public with sharing class ReimbursementService {

    /**
     * @description Generates reimbursement records for approved expense reports without existing payouts.
     * @param approvedReports List of approved Expense_Report__c records
     */
    public static void generateReimbursementsForApprovedReports(List<Expense_Report__c> approvedReports) {
        if (approvedReports == null || approvedReports.isEmpty()) {
            return;
        }

        Set<Id> reportIds = new Set<Id>();
        for (Expense_Report__c rep : approvedReports) {
            reportIds.add(rep.Id);
        }

        // Avoid duplicate reimbursement creation
        Map<Id, Reimbursement__c> existingReimbursements = new Map<Id, Reimbursement__c>();
        for (Reimbursement__c r : [
            SELECT Id, Expense_Report__c
            FROM Reimbursement__c
            WHERE Expense_Report__c IN :reportIds
        ]) {
            existingReimbursements.put(r.Expense_Report__c, r);
        }

        List<Reimbursement__c> newReimbursements = new List<Reimbursement__c>();
        for (Expense_Report__c rep : approvedReports) {
            if (!existingReimbursements.containsKey(rep.Id)) {
                Decimal amountToReimburse = rep.Total_Reimbursable_Amount__c != null && rep.Total_Reimbursable_Amount__c > 0
                    ? rep.Total_Reimbursable_Amount__c
                    : (rep.Total_Amount__c != null ? rep.Total_Amount__c : 0);

                if (amountToReimburse > 0) {
                    newReimbursements.add(new Reimbursement__c(
                        Expense_Report__c = rep.Id,
                        Employee__c = rep.Employee__c,
                        Approved_Amount__c = amountToReimburse,
                        Reimbursement_Status__c = 'Pending',
                        Payment_Method__c = 'Direct Deposit / Bank Transfer',
                        Processing_Date__c = Date.today(),
                        Comments__c = 'Auto-generated upon expense report approval.'
                    ));
                }
            }
        }

        if (!newReimbursements.isEmpty() && Schema.sObjectType.Reimbursement__c.isCreateable()) {
            insert newReimbursements;

            // Trigger asynchronous payout processing
            List<Id> rmbIds = new List<Id>();
            for (Reimbursement__c rmb : newReimbursements) {
                rmbIds.add(rmb.Id);
            }
            System.enqueueJob(new ProcessReimbursementQueueable(rmbIds));
        }
    }
}
