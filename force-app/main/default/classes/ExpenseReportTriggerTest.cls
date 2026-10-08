@IsTest
private class ExpenseReportTriggerTest {

    @IsTest
    static void testExpenseReportApprovalGeneratesReimbursement() {
        Travel_Request__c tr = TravelEasyTestDataFactory.createTravelRequest(null, 'Chennai', 40000);
        Expense_Report__c er = TravelEasyTestDataFactory.createExpenseReport(tr.Id, null);
        Expense_Item__c item = TravelEasyTestDataFactory.createExpenseItem(er.Id, 'Meals & Food', 400, true);

        Test.startTest();
        update new Expense_Report__c(Id = er.Id, Approval_Status__c = 'Approved');
        Test.stopTest();

        Expense_Report__c updatedReport = [
            SELECT Id, Status__c, Reimbursement_Status__c
            FROM Expense_Report__c
            WHERE Id = :er.Id
        ];
        System.assertEquals('Reimbursed', updatedReport.Status__c, 'Report status should transition to Reimbursed via Queueable execution.');

        List<Reimbursement__c> reimbursements = [
            SELECT Id, Approved_Amount__c, Reimbursement_Status__c
            FROM Reimbursement__c
            WHERE Expense_Report__c = :er.Id
        ];
        System.assert(!reimbursements.isEmpty(), 'A Reimbursement record should be auto-created upon approval.');
        System.assertEquals(400, reimbursements[0].Approved_Amount__c, 'Approved amount should match expense reimbursable total.');
    }
}
