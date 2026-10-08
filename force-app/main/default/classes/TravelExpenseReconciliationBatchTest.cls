@IsTest
private class TravelExpenseReconciliationBatchTest {

    @IsTest
    static void testBatchReconciliation() {
        Travel_Request__c tr = TravelEasyTestDataFactory.createTravelRequest(null, 'Noida', 100000);
        Expense_Report__c er = TravelEasyTestDataFactory.createExpenseReport(tr.Id, null);

        // Create 10 items
        List<Expense_Item__c> items = TravelEasyTestDataFactory.createMultipleExpenseItems(er.Id, 10, 'Meals & Food', 400);

        Test.startTest();
        TravelExpenseReconciliationBatch batchJob = new TravelExpenseReconciliationBatch();
        Database.executeBatch(batchJob, 50);
        Test.stopTest();

        List<Integration_Log__c> logs = [
            SELECT Id, Service_Name__c, Status__c
            FROM Integration_Log__c
            WHERE Service_Name__c = 'TravelExpenseReconciliationBatch'
        ];
        System.assert(!logs.isEmpty(), 'Batch execution must log audit summary to Integration_Log__c.');
        System.assertEquals('Success', logs[0].Status__c, 'Batch execution log should be Success.');
    }
}
