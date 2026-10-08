@IsTest
private class ReimbursementTriggerTest {

    @IsTest
    static void testReimbursementLifecycle() {
        Travel_Request__c tr = TravelEasyTestDataFactory.createTravelRequest(null, 'Ahmedabad', 20000);
        Expense_Report__c er = TravelEasyTestDataFactory.createExpenseReport(tr.Id, null);

        Reimbursement__c rmb = new Reimbursement__c(
            Expense_Report__c = er.Id,
            Approved_Amount__c = 1500,
            Reimbursement_Status__c = 'Pending'
        );
        insert rmb;

        Test.startTest();
        rmb.Reimbursement_Status__c = 'Completed';
        rmb.Payment_Reference__c = 'PAY-TEST-999';
        update rmb;
        Test.stopTest();

        Expense_Report__c updatedReport = [
            SELECT Id, Status__c, Reimbursement_Status__c
            FROM Expense_Report__c
            WHERE Id = :er.Id
        ];
        System.assertEquals('Reimbursed', updatedReport.Reimbursement_Status__c, 'Report reimbursement status should be Reimbursed.');
    }
}
