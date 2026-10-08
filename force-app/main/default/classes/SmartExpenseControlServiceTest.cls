@IsTest
private class SmartExpenseControlServiceTest {

    @IsTest
    static void testNormalExpenseValidation() {
        Travel_Request__c tr = TravelEasyTestDataFactory.createTravelRequest(null, 'Bangalore', 50000);
        Expense_Report__c er = TravelEasyTestDataFactory.createExpenseReport(tr.Id, null);

        Test.startTest();
        Expense_Item__c item = TravelEasyTestDataFactory.createExpenseItem(er.Id, 'Meals & Food', 450, true);
        Test.stopTest();

        Expense_Item__c evaluated = [
            SELECT Id, Validation_Status__c, Policy_Result__c
            FROM Expense_Item__c
            WHERE Id = :item.Id
        ];
        System.assertEquals('Passed', evaluated.Validation_Status__c, 'Valid expense below policy threshold should pass validation.');
        System.assertEquals('Pass', evaluated.Policy_Result__c, 'Policy result should be Pass.');
    }

    @IsTest
    static void testPolicyLimitExceededException() {
        Travel_Request__c tr = TravelEasyTestDataFactory.createTravelRequest(null, 'Mumbai', 50000);
        Expense_Report__c er = TravelEasyTestDataFactory.createExpenseReport(tr.Id, null);

        Test.startTest();
        // Meals limit is 2000, 3500 exceeds policy
        Expense_Item__c item = TravelEasyTestDataFactory.createExpenseItem(er.Id, 'Meals & Food', 3500, true);
        Test.stopTest();

        Expense_Item__c evaluated = [
            SELECT Id, Validation_Status__c, Policy_Result__c, Exception_Reason__c
            FROM Expense_Item__c
            WHERE Id = :item.Id
        ];
        System.assertEquals('Exception Detected', evaluated.Validation_Status__c, 'Excessive expense should trigger exception.');
        System.assertEquals('Policy Exception', evaluated.Policy_Result__c, 'Policy result should be Policy Exception.');

        List<Expense_Validation_Exception__c> exceptions = [
            SELECT Id, Exception_Type__c, Severity__c
            FROM Expense_Validation_Exception__c
            WHERE Expense_Item__c = :item.Id
        ];
        System.assert(!exceptions.isEmpty(), 'An Exception record must be created.');
        System.assertEquals('Policy Limit Exceeded', exceptions[0].Exception_Type__c, 'Exception type should match.');
    }

    @IsTest
    static void testMissingReceiptException() {
        Travel_Request__c tr = TravelEasyTestDataFactory.createTravelRequest(null, 'Delhi', 50000);
        Expense_Report__c er = TravelEasyTestDataFactory.createExpenseReport(tr.Id, null);

        Test.startTest();
        // Meals threshold for receipt is 500. 1200 without receipt should trigger missing receipt
        Expense_Item__c item = TravelEasyTestDataFactory.createExpenseItem(er.Id, 'Meals & Food', 1200, false);
        Test.stopTest();

        Expense_Item__c evaluated = [
            SELECT Id, Validation_Status__c, Policy_Result__c
            FROM Expense_Item__c
            WHERE Id = :item.Id
        ];
        System.assertEquals('Exception Detected', evaluated.Validation_Status__c, 'Missing receipt above threshold should trigger exception.');
        System.assertEquals('Missing Receipt', evaluated.Policy_Result__c, 'Policy result should be Missing Receipt.');
    }

    @IsTest
    static void testPotentialDuplicateException() {
        Travel_Request__c tr = TravelEasyTestDataFactory.createTravelRequest(null, 'Hyderabad', 50000);
        Expense_Report__c er = TravelEasyTestDataFactory.createExpenseReport(tr.Id, null);

        Expense_Item__c item1 = new Expense_Item__c(
            Expense_Report__c = er.Id,
            Expense_Category__c = 'Meals & Food',
            Amount__c = 400,
            Expense_Date__c = Date.today(),
            Vendor__c = 'Saravana Bhavan',
            Description__c = 'Client lunch',
            Receipt_Attached__c = true
        );
        insert item1;

        Test.startTest();
        Expense_Item__c duplicateItem = new Expense_Item__c(
            Expense_Report__c = er.Id,
            Expense_Category__c = 'Meals & Food',
            Amount__c = 400,
            Expense_Date__c = Date.today(),
            Vendor__c = 'Saravana Bhavan',
            Description__c = 'Client lunch repeated',
            Receipt_Attached__c = true
        );
        insert duplicateItem;
        Test.stopTest();

        Expense_Item__c evaluated = [
            SELECT Id, Validation_Status__c, Policy_Result__c, Is_Duplicate_Flag__c
            FROM Expense_Item__c
            WHERE Id = :duplicateItem.Id
        ];
        System.assertEquals('Exception Detected', evaluated.Validation_Status__c, 'Duplicate expense should be detected.');
        System.assertEquals('Potential Duplicate', evaluated.Policy_Result__c, 'Policy result must indicate duplicate.');
        System.assertEquals(true, evaluated.Is_Duplicate_Flag__c, 'Duplicate flag must be set.');
    }

    @IsTest
    static void testBudgetOverrunException() {
        // Estimated budget is 5,000
        Travel_Request__c tr = TravelEasyTestDataFactory.createTravelRequest(null, 'Pune', 5000);
        Expense_Report__c er = TravelEasyTestDataFactory.createExpenseReport(tr.Id, null);

        Test.startTest();
        // Airfare of 20,000 exceeds trip budget of 5,000 by 300%
        Expense_Item__c item = TravelEasyTestDataFactory.createExpenseItem(er.Id, 'Airfare', 20000, true);
        Test.stopTest();

        Expense_Item__c evaluated = [
            SELECT Id, Validation_Status__c, Policy_Result__c
            FROM Expense_Item__c
            WHERE Id = :item.Id
        ];
        System.assertEquals('Exception Detected', evaluated.Validation_Status__c, 'Over budget expense must trigger exception.');
        System.assertEquals('Budget Overrun', evaluated.Policy_Result__c, 'Policy result must be Budget Overrun.');
    }

    @IsTest
    static void testBulkExpenseEvaluation() {
        Travel_Request__c tr = TravelEasyTestDataFactory.createTravelRequest(null, 'Kolkata', 500000);
        Expense_Report__c er = TravelEasyTestDataFactory.createExpenseReport(tr.Id, null);

        Test.startTest();
        List<Expense_Item__c> bulkItems = TravelEasyTestDataFactory.createMultipleExpenseItems(er.Id, 50, 'Meals & Food', 300);
        Test.stopTest();

        List<Expense_Item__c> evaluated = [
            SELECT Id, Validation_Status__c
            FROM Expense_Item__c
            WHERE Expense_Report__c = :er.Id
        ];
        System.assertEquals(50, evaluated.size(), 'All 50 records must be processed without SOQL/DML governor limit errors.');
    }
}
