@IsTest
private class ApprovalSLAMonitorSchedulableTest {

    @IsTest
    static void testSchedulableExecution() {
        Travel_Request__c tr = TravelEasyTestDataFactory.createTravelRequest(null, 'Chandigarh', 15000);
        tr.Status__c = 'Under Approval';
        tr.Approval_Status__c = 'Pending';
        update tr;

        Test.startTest();
        String cronExpr = '0 0 12 * * ?';
        String jobId = System.schedule('TestTravelEasySLAMonitor', cronExpr, new ApprovalSLAMonitorSchedulable());
        // Run direct method execution for instant code path validation
        Integer escalations = ApprovalSLAMonitorSchedulable.monitorPendingApprovals();
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Scheduled job must be registered.');
        System.assert(escalations >= 0, 'SLA monitor must execute cleanly.');
    }
}
