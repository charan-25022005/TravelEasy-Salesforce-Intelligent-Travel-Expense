@IsTest
private class ExpenseItemTriggerTest {

    @IsTest
    static void testReimbursableCalculation() {
        Travel_Request__c tr = TravelEasyTestDataFactory.createTravelRequest(null, 'Kochi', 30000);
        Expense_Report__c er = TravelEasyTestDataFactory.createExpenseReport(tr.Id, null);

        Expense_Item__c cashItem = new Expense_Item__c(
            Expense_Report__c = er.Id,
            Expense_Category__c = 'Meals & Food',
            Amount__c = 350,
            Paid_By__c = 'Personal Cash / Card'
        );

        Expense_Item__c corpItem = new Expense_Item__c(
            Expense_Report__c = er.Id,
            Expense_Category__c = 'Hotel / Lodging',
            Amount__c = 5000,
            Paid_By__c = 'Corporate Card',
            Receipt_Attached__c = true
        );

        Test.startTest();
        insert new List<Expense_Item__c>{ cashItem, corpItem };
        Test.stopTest();

        Expense_Item__c evaluatedCash = [SELECT Reimbursable_Amount__c FROM Expense_Item__c WHERE Id = :cashItem.Id];
        Expense_Item__c evaluatedCorp = [SELECT Reimbursable_Amount__c FROM Expense_Item__c WHERE Id = :corpItem.Id];

        System.assertEquals(350, evaluatedCash.Reimbursable_Amount__c, 'Personal expense should be 100% reimbursable.');
        System.assertEquals(0, evaluatedCorp.Reimbursable_Amount__c, 'Corporate card expense should have zero direct reimbursement to employee.');
    }
}
