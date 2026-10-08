@IsTest
private class TravelRequestTriggerTest {

    @IsTest
    static void testTravelRequestLifecycle() {
        Travel_Request__c tr = TravelEasyTestDataFactory.createTravelRequest(null, 'Goa', 30000);
        System.assertEquals('Draft', tr.Status__c, 'Initial status must be Draft.');

        Test.startTest();
        tr.Status__c = 'Under Approval';
        tr.Approval_Status__c = 'Approved';
        update tr;
        Test.stopTest();

        Travel_Request__c updated = [SELECT Id, Status__c, Approval_Status__c FROM Travel_Request__c WHERE Id = :tr.Id];
        System.assertEquals('Approved', updated.Status__c, 'Status should transition to Approved.');
    }

    @IsTest
    static void testBulkTravelRequests() {
        List<Travel_Request__c> requests = new List<Travel_Request__c>();
        for (Integer i = 0; i < 50; i++) {
            requests.add(new Travel_Request__c(
                Destination__c = 'City ' + i,
                Purpose__c = 'Meeting ' + i,
                Start_Date__c = Date.today().addDays(i + 1),
                End_Date__c = Date.today().addDays(i + 3),
                Travel_Type__c = 'Domestic',
                Estimated_Cost__c = 10000 + i,
                Status__c = 'Draft'
            ));
        }

        Test.startTest();
        insert requests;
        Test.stopTest();

        System.assertEquals(50, [SELECT count() FROM Travel_Request__c], 'Bulk requests should insert cleanly.');
    }
}
