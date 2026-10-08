/**
 * @description Trigger Handler for Travel_Request__c.
 * Architecture: Follows One-Trigger-Per-Object pattern with distinct lifecycle stages.
 */
public with sharing class TravelRequestTriggerHandler {

    public static void handleBeforeInsert(List<Travel_Request__c> newRecords) {
        for (Travel_Request__c tr : newRecords) {
            if (tr.Employee__c == null) {
                tr.Employee__c = UserInfo.getUserId();
            }
            if (String.isBlank(tr.Status__c)) {
                tr.Status__c = 'Draft';
            }
            if (String.isBlank(tr.Approval_Status__c)) {
                tr.Approval_Status__c = 'Pending';
            }
        }
    }

    public static void handleBeforeUpdate(List<Travel_Request__c> newRecords, Map<Id, Travel_Request__c> oldMap) {
        for (Travel_Request__c tr : newRecords) {
            Travel_Request__c old = oldMap.get(tr.Id);
            // Synchronize status when approval status changes
            if (tr.Approval_Status__c != old.Approval_Status__c) {
                if (tr.Approval_Status__c == 'Approved') {
                    tr.Status__c = 'Approved';
                } else if (tr.Approval_Status__c == 'Rejected') {
                    tr.Status__c = 'Rejected';
                }
            }
        }
    }

    public static void handleAfterInsert(List<Travel_Request__c> newRecords) {
        // Post-insert integrations or notification logic
    }

    public static void handleAfterUpdate(List<Travel_Request__c> newRecords, Map<Id, Travel_Request__c> oldMap) {
        // Post-update lifecycle transitions
    }
}
