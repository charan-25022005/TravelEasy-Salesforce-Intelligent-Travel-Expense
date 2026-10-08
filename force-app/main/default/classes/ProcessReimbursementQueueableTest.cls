@IsTest
private class ProcessReimbursementQueueableTest {

    @IsTest
    static void testQueueableExecution() {
        Travel_Request__c tr = TravelEasyTestDataFactory.createTravelRequest(null, 'Jaipur', 25000);
        Expense_Report__c er = TravelEasyTestDataFactory.createExpenseReport(tr.Id, null);

        Reimbursement__c rmb = new Reimbursement__c(
            Expense_Report__c = er.Id,
            Approved_Amount__c = 3200,
            Reimbursement_Status__c = 'Pending',
            Payment_Method__c = 'Direct Deposit / Bank Transfer'
        );
        insert rmb;

        Test.startTest();
        System.enqueueJob(new ProcessReimbursementQueueable(new List<Id>{ rmb.Id }));
        Test.stopTest();

        Reimbursement__c processed = [
            SELECT Id, Reimbursement_Status__c, Payment_Reference__c, Bank_Transaction_Id__c
            FROM Reimbursement__c
            WHERE Id = :rmb.Id
        ];
        System.assertEquals('Completed', processed.Reimbursement_Status__c, 'Queueable job should mark reimbursement Completed.');
        System.assert(String.isNotBlank(processed.Payment_Reference__c), 'Payment reference must be generated.');
        System.assert(String.isNotBlank(processed.Bank_Transaction_Id__c), 'Bank transaction ID must be populated.');

        List<Integration_Log__c> logs = [
            SELECT Id, Service_Name__c, Status__c, Status_Code__c
            FROM Integration_Log__c
            WHERE Related_Record_Id__c = :rmb.Id
        ];
        System.assert(!logs.isEmpty(), 'Integration log must be created.');
        System.assertEquals('Success', logs[0].Status__c, 'Log status should be Success.');
        System.assertEquals(200, logs[0].Status_Code__c, 'HTTP code should be 200.');
    }
}
