@IsTest
private class TripWalletControllerTest {

    @IsTest
    static void testGetTripWalletDetails() {
        Travel_Request__c tr = TravelEasyTestDataFactory.createTravelRequest(null, 'Bangalore', 50000);
        Expense_Report__c er = TravelEasyTestDataFactory.createExpenseReport(tr.Id, null);
        TravelEasyTestDataFactory.createExpenseItem(er.Id, 'Meals & Food', 450, true);

        Test.startTest();
        TripWalletController.TripWalletSummary summary = TripWalletController.getTripWalletDetails(tr.Id);
        List<TripWalletController.ExpenseItemDTO> items = TripWalletController.getExpenseItems(tr.Id);
        Test.stopTest();

        System.assertEquals(tr.Id, summary.travelRequestId, 'Travel request ID must match.');
        System.assertEquals(50000, summary.estimatedCost, 'Estimated cost must match.');
        System.assertEquals(1, summary.totalExpenseItems, 'Item count should be 1.');
        System.assert(!items.isEmpty(), 'Items list should not be empty.');
        System.assertEquals('Meals & Food', items[0].category, 'Category should match.');
    }

    @IsTest
    static void testSubmitQuickExpense() {
        Travel_Request__c tr = TravelEasyTestDataFactory.createTravelRequest(null, 'Chennai', 35000);

        Test.startTest();
        Id itemId = TripWalletController.submitQuickExpense(
            tr.Id,
            'Ground Transportation / Taxi',
            450,
            Date.today(),
            'Uber',
            'Airport cab to client site',
            true
        );
        Test.stopTest();

        System.assertNotEquals(null, itemId, 'Quick expense item must be created.');
        Expense_Item__c created = [
            SELECT Id, Vendor__c, Amount__c, Validation_Status__c
            FROM Expense_Item__c
            WHERE Id = :itemId
        ];
        System.assertEquals('Uber', created.Vendor__c, 'Vendor must match.');
        System.assertEquals(450, created.Amount__c, 'Amount must match.');
    }
}
