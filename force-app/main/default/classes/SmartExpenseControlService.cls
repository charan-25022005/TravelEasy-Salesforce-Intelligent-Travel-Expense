/**
 * @description Smart Expense Control Engine
 * Differentiator: Explainable, deterministic policy compliance, duplicate detection,
 * receipt validation, and budget overrun prevention.
 * Principle: Automate normal cases. Escalate exceptions. Never blindly automate high-risk financial decisions.
 */
public with sharing class SmartExpenseControlService {

    public class ValidationResult {
        public Boolean hasException { get; set; }
        public String policyResult { get; set; }
        public String exceptionType { get; set; }
        public String severity { get; set; }
        public String reason { get; set; }
        public Boolean isDuplicate { get; set; }

        public ValidationResult() {
            this.hasException = false;
            this.policyResult = 'Pass';
            this.isDuplicate = false;
        }
    }

    /**
     * @description Runs in beforeInsert / beforeUpdate to evaluate items and populate fields on Expense_Item__c.
     */
    public static void evaluateExpenseItemsBefore(List<Expense_Item__c> items) {
        if (items == null || items.isEmpty()) {
            return;
        }

        Set<Id> reportIds = new Set<Id>();
        for (Expense_Item__c item : items) {
            if (item.Expense_Report__c != null) {
                reportIds.add(item.Expense_Report__c);
            }
        }

        Map<Id, Expense_Report__c> reportsMap = new Map<Id, Expense_Report__c>([
            SELECT Id, Employee__c, Status__c, Travel_Request__c,
                   Travel_Request__r.Estimated_Cost__c,
                   Travel_Request__r.Actual_Total_Expense__c,
                   Travel_Request__r.Status__c
            FROM Expense_Report__c
            WHERE Id IN :reportIds
        ]);

        Map<String, Travel_Expense_Policy__mdt> policyMap = getActivePolicies();

        Set<Id> employeeIds = new Set<Id>();
        for (Expense_Report__c rep : reportsMap.values()) {
            if (rep.Employee__c != null) {
                employeeIds.add(rep.Employee__c);
            }
        }

        List<Expense_Item__c> existingItems = [
            SELECT Id, Expense_Report__c, Expense_Report__r.Employee__c,
                   Expense_Category__c, Amount__c, Expense_Date__c, Vendor__c
            FROM Expense_Item__c
            WHERE (Expense_Report__c IN :reportIds OR Expense_Report__r.Employee__c IN :employeeIds)
            LIMIT 1000
        ];

        for (Expense_Item__c item : items) {
            Expense_Report__c parentReport = reportsMap.get(item.Expense_Report__c);
            ValidationResult vr = evaluateSingleItem(item, parentReport, policyMap, existingItems, items);

            if (vr.hasException) {
                item.Validation_Status__c = 'Exception Detected';
                item.Policy_Result__c = vr.policyResult;
                item.Exception_Reason__c = vr.reason;
                item.Is_Duplicate_Flag__c = vr.isDuplicate;
            } else {
                item.Validation_Status__c = 'Passed';
                item.Policy_Result__c = 'Pass';
                item.Exception_Reason__c = null;
                item.Is_Duplicate_Flag__c = false;
            }
        }
    }

    /**
     * @description Runs in afterInsert / afterUpdate to create Expense_Validation_Exception__c records
     * and update parent Expense_Report__c status.
     */
    public static void createExceptionsAfter(List<Expense_Item__c> items) {
        if (items == null || items.isEmpty()) {
            return;
        }

        Set<Id> reportIds = new Set<Id>();
        Set<Id> itemIds = new Set<Id>();
        for (Expense_Item__c itm : items) {
            if (itm.Expense_Report__c != null) {
                reportIds.add(itm.Expense_Report__c);
            }
            if (itm.Id != null) {
                itemIds.add(itm.Id);
            }
        }

        Map<Id, Expense_Report__c> reportsMap = new Map<Id, Expense_Report__c>([
            SELECT Id, Travel_Request__c
            FROM Expense_Report__c
            WHERE Id IN :reportIds
        ]);

        Map<String, Travel_Expense_Policy__mdt> policyMap = getActivePolicies();

        List<Expense_Validation_Exception__c> exceptionsToInsert = new List<Expense_Validation_Exception__c>();
        Map<Id, Boolean> reportExceptionFlagMap = new Map<Id, Boolean>();

        for (Expense_Item__c item : items) {
            Expense_Report__c parentReport = reportsMap.get(item.Expense_Report__c);

            if (item.Validation_Status__c == 'Exception Detected') {
                String excType = 'Human Review Required';
                String severity = 'Medium';
                if (item.Policy_Result__c == 'Policy Exception') {
                    excType = 'Policy Limit Exceeded';
                    severity = 'High';
                } else if (item.Policy_Result__c == 'Missing Receipt') {
                    excType = 'Missing Receipt';
                    severity = 'Medium';
                } else if (item.Policy_Result__c == 'Potential Duplicate') {
                    excType = 'Potential Duplicate';
                    severity = 'High';
                } else if (item.Policy_Result__c == 'Budget Overrun') {
                    excType = 'Budget Overrun';
                    severity = 'Critical';
                }

                exceptionsToInsert.add(new Expense_Validation_Exception__c(
                    Expense_Item__c = item.Id,
                    Expense_Report__c = item.Expense_Report__c,
                    Travel_Request__c = parentReport != null ? parentReport.Travel_Request__c : null,
                    Exception_Type__c = excType,
                    Severity__c = severity,
                    Exception_Message__c = item.Exception_Reason__c,
                    Status__c = 'Open'
                ));
                reportExceptionFlagMap.put(item.Expense_Report__c, true);
            } else {
                if (!reportExceptionFlagMap.containsKey(item.Expense_Report__c)) {
                    reportExceptionFlagMap.put(item.Expense_Report__c, false);
                }
            }
        }

        if (!exceptionsToInsert.isEmpty() && Schema.sObjectType.Expense_Validation_Exception__c.isCreateable()) {
            insert exceptionsToInsert;
        }

        updateParentReportStatus(reportExceptionFlagMap);
    }

    /**
     * @description Batch context evaluation method.
     */
    public static void evaluateExpenseItems(List<Expense_Item__c> items) {
        evaluateExpenseItemsBefore(items);
        createExceptionsAfter(items);
    }

    /**
     * @description Core rule evaluation for a single line item.
     */
    private static ValidationResult evaluateSingleItem(
        Expense_Item__c item,
        Expense_Report__c parentReport,
        Map<String, Travel_Expense_Policy__mdt> policyMap,
        List<Expense_Item__c> existingItems,
        List<Expense_Item__c> currentBatch
    ) {
        ValidationResult vr = new ValidationResult();

        // Rule 1: Validate Amount
        if (item.Amount__c == null || item.Amount__c <= 0) {
            vr.hasException = true;
            vr.policyResult = 'Verification Required';
            vr.exceptionType = 'Human Review Required';
            vr.severity = 'Critical';
            vr.reason = 'Expense amount must be strictly greater than zero.';
            return vr;
        }

        // Rule 2: Check Policy Configuration Limits
        Travel_Expense_Policy__mdt policy = policyMap.get(item.Expense_Category__c);
        if (policy != null && policy.Is_Active__c) {
            // Check Single Transaction Limit
            if (policy.Single_Transaction_Limit__c != null && item.Amount__c > policy.Single_Transaction_Limit__c) {
                vr.hasException = true;
                vr.policyResult = 'Policy Exception';
                vr.exceptionType = 'Policy Limit Exceeded';
                vr.severity = 'High';
                vr.reason = 'Amount of ' + item.Amount__c + ' exceeds allowable policy limit of ' +
                            policy.Single_Transaction_Limit__c + ' for category ' + item.Expense_Category__c + '.';
                return vr;
            }

            // Check Receipt Requirement
            if (policy.Receipt_Required_Threshold__c != null && item.Amount__c >= policy.Receipt_Required_Threshold__c) {
                if (item.Receipt_Attached__c != true && String.isBlank(item.Receipt_Document_Id__c)) {
                    vr.hasException = true;
                    vr.policyResult = 'Missing Receipt';
                    vr.exceptionType = 'Missing Receipt';
                    vr.severity = 'Medium';
                    vr.reason = 'Receipt is mandatory for expenses over ' + policy.Receipt_Required_Threshold__c +
                                ' in category ' + item.Expense_Category__c + '.';
                    return vr;
                }
            }
        }

        // Rule 3: Check Duplicate Expense
        if (isDuplicateExpense(item, existingItems, currentBatch)) {
            vr.hasException = true;
            vr.policyResult = 'Potential Duplicate';
            vr.exceptionType = 'Potential Duplicate';
            vr.severity = 'High';
            vr.isDuplicate = true;
            vr.reason = 'Potential duplicate detected: identical vendor, date, category, and amount (' +
                        item.Amount__c + ') was previously recorded.';
            return vr;
        }

        // Rule 4: Check Budget Overrun against Travel Request
        if (parentReport != null && parentReport.Travel_Request__r != null) {
            Decimal estCost = parentReport.Travel_Request__r.Estimated_Cost__c != null ? parentReport.Travel_Request__r.Estimated_Cost__c : 0;
            Decimal actualSpent = parentReport.Travel_Request__r.Actual_Total_Expense__c != null ? parentReport.Travel_Request__r.Actual_Total_Expense__c : 0;
            Decimal projectedSpend = actualSpent + (item.Id == null ? item.Amount__c : 0);

            if (estCost > 0 && projectedSpend > (estCost * 1.10)) {
                vr.hasException = true;
                vr.policyResult = 'Budget Overrun';
                vr.exceptionType = 'Budget Overrun';
                vr.severity = 'Critical';
                vr.reason = 'Projected total expenses (' + projectedSpend + ') exceed approved trip budget (' +
                            estCost + ') by more than 10%. Variance: ' + (projectedSpend - estCost) + '.';
                return vr;
            }
        }

        return vr;
    }

    private static Boolean isDuplicateExpense(
        Expense_Item__c target,
        List<Expense_Item__c> existingItems,
        List<Expense_Item__c> currentBatch
    ) {
        if (target.Amount__c == null || target.Expense_Date__c == null) {
            return false;
        }

        for (Expense_Item__c ex : existingItems) {
            if (ex.Id != target.Id &&
                ex.Expense_Category__c == target.Expense_Category__c &&
                ex.Amount__c == target.Amount__c &&
                ex.Expense_Date__c == target.Expense_Date__c &&
                String.isNotBlank(target.Vendor__c) &&
                ex.Vendor__c != null &&
                ex.Vendor__c.equalsIgnoreCase(target.Vendor__c)) {
                return true;
            }
        }

        for (Expense_Item__c cur : currentBatch) {
            if (cur !== target &&
                cur.Expense_Category__c == target.Expense_Category__c &&
                cur.Amount__c == target.Amount__c &&
                cur.Expense_Date__c == target.Expense_Date__c &&
                String.isNotBlank(target.Vendor__c) &&
                cur.Vendor__c != null &&
                cur.Vendor__c.equalsIgnoreCase(target.Vendor__c)) {
                return true;
            }
        }

        return false;
    }

    private static Map<String, Travel_Expense_Policy__mdt> getActivePolicies() {
        Map<String, Travel_Expense_Policy__mdt> policies = new Map<String, Travel_Expense_Policy__mdt>();
        try {
            List<Travel_Expense_Policy__mdt> mdtList = [
                SELECT MasterLabel, DeveloperName, Category__c, Daily_Limit__c,
                       Single_Transaction_Limit__c, Receipt_Required_Threshold__c,
                       Allowed_Payment_Methods__c, Requires_Manager_Review__c, Is_Active__c
                FROM Travel_Expense_Policy__mdt
                WHERE Is_Active__c = true
            ];
            for (Travel_Expense_Policy__mdt p : mdtList) {
                if (String.isNotBlank(p.Category__c)) {
                    policies.put(p.Category__c, p);
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Custom metadata query fallback: ' + e.getMessage());
        }
        return policies;
    }

    private static void updateParentReportStatus(Map<Id, Boolean> reportExceptionFlagMap) {
        if (reportExceptionFlagMap.isEmpty()) {
            return;
        }

        List<Expense_Report__c> reportsToUpdate = new List<Expense_Report__c>();
        for (Id repId : reportExceptionFlagMap.keySet()) {
            Boolean hasExc = reportExceptionFlagMap.get(repId);
            reportsToUpdate.add(new Expense_Report__c(
                Id = repId,
                Has_Exceptions__c = hasExc,
                Validation_Status__c = hasExc ? 'Policy Exceptions Detected' : 'Passed'
            ));
        }

        if (Schema.sObjectType.Expense_Report__c.isUpdateable()) {
            update reportsToUpdate;
        }
    }
}
