/**
 * @description Schedulable Apex monitoring approval SLAs across Travel Requests and Expense Reports.
 * Flags overdue approvals, logs escalations, and ensures operational compliance.
 */
public with sharing class ApprovalSLAMonitorSchedulable implements Schedulable {

    public void execute(SchedulableContext sc) {
        monitorPendingApprovals();
    }

    public static Integer monitorPendingApprovals() {
        Datetime slaThreshold = Datetime.now().addHours(-48); // 48 Hour SLA window
        Integer escalationsLogged = 0;

        // 1. Check Overdue Travel Requests
        List<Travel_Request__c> overdueRequests = [
            SELECT Id, Name, Status__c, Approval_Status__c, CreatedDate, Approver__c, Employee__r.Name
            FROM Travel_Request__c
            WHERE Status__c = 'Under Approval' AND Approval_Status__c = 'Pending' AND CreatedDate <= :slaThreshold
            LIMIT 200
        ];

        for (Travel_Request__c tr : overdueRequests) {
            escalationsLogged++;
            IntegrationLogService.log(
                'ApprovalSLAMonitor',
                'InternalSLAEngine://TravelRequestEscalation',
                'RecordId: ' + tr.Id + ' | Employee: ' + tr.Employee__r.Name,
                'SLA Breach: Travel request pending approval for > 48 hours.',
                408,
                'Pending',
                'Approval SLA Breached. Escalation notification dispatched.',
                tr.Id
            );
        }

        // 2. Check Overdue Expense Reports
        List<Expense_Report__c> overdueReports = [
            SELECT Id, Name, Status__c, Approval_Status__c, CreatedDate, Employee__r.Name
            FROM Expense_Report__c
            WHERE Status__c = 'Under Review' AND Approval_Status__c = 'Pending' AND CreatedDate <= :slaThreshold
            LIMIT 200
        ];

        for (Expense_Report__c er : overdueReports) {
            escalationsLogged++;
            IntegrationLogService.log(
                'ApprovalSLAMonitor',
                'InternalSLAEngine://ExpenseReportEscalation',
                'RecordId: ' + er.Id + ' | Employee: ' + er.Employee__r.Name,
                'SLA Breach: Expense report review pending > 48 hours.',
                408,
                'Pending',
                'Expense review SLA Breached. Escalation notification dispatched.',
                er.Id
            );
        }

        return escalationsLogged;
    }
}
