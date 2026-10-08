/**
 * @description Controller for the Trip Wallet Lightning Web Component.
 * Surfaces real-time budget utilization, live spend tracking, category breakdown,
 * and seamless quick expense creation directly from the trip view.
 */
public with sharing class TripWalletController {

    public class TripWalletSummary {
        @AuraEnabled public Id travelRequestId { get; set; }
        @AuraEnabled public String travelRequestNumber { get; set; }
        @AuraEnabled public String destination { get; set; }
        @AuraEnabled public String purpose { get; set; }
        @AuraEnabled public Date startDate { get; set; }
        @AuraEnabled public Date endDate { get; set; }
        @AuraEnabled public Decimal estimatedCost { get; set; }
        @AuraEnabled public Decimal actualSpent { get; set; }
        @AuraEnabled public Decimal remainingBudget { get; set; }
        @AuraEnabled public Decimal utilizationPercent { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Integer totalExpenseItems { get; set; }
        @AuraEnabled public Integer openExceptionCount { get; set; }
        @AuraEnabled public List<ExpenseCategorySpend> categoryBreakdown { get; set; }
    }

    public class ExpenseCategorySpend {
        @AuraEnabled public String category { get; set; }
        @AuraEnabled public Decimal totalAmount { get; set; }
        @AuraEnabled public Integer itemCount { get; set; }
    }

    public class ExpenseItemDTO {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String category { get; set; }
        @AuraEnabled public Decimal amount { get; set; }
        @AuraEnabled public Date expenseDate { get; set; }
        @AuraEnabled public String vendor { get; set; }
        @AuraEnabled public String validationStatus { get; set; }
        @AuraEnabled public String policyResult { get; set; }
        @AuraEnabled public Boolean receiptAttached { get; set; }
        @AuraEnabled public String exceptionReason { get; set; }
        @AuraEnabled public Boolean isDuplicate { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static TripWalletSummary getTripWalletDetails(Id travelRequestId) {
        if (travelRequestId == null) {
            throw new AuraHandledException('Travel Request ID is required.');
        }

        Travel_Request__c tr = [
            SELECT Id, Name, Destination__c, Purpose__c, Start_Date__c, End_Date__c,
                   Estimated_Cost__c, Actual_Total_Expense__c, Remaining_Budget__c,
                   Budget_Utilization_Percent__c, Status__c
            FROM Travel_Request__c
            WHERE Id = :travelRequestId
            LIMIT 1
        ];

        TripWalletSummary summary = new TripWalletSummary();
        summary.travelRequestId = tr.Id;
        summary.travelRequestNumber = tr.Name;
        summary.destination = tr.Destination__c;
        summary.purpose = tr.Purpose__c;
        summary.startDate = tr.Start_Date__c;
        summary.endDate = tr.End_Date__c;
        summary.estimatedCost = tr.Estimated_Cost__c != null ? tr.Estimated_Cost__c : 0.00;
        summary.actualSpent = tr.Actual_Total_Expense__c != null ? tr.Actual_Total_Expense__c : 0.00;
        summary.remainingBudget = tr.Remaining_Budget__c != null ? tr.Remaining_Budget__c : (summary.estimatedCost - summary.actualSpent);
        summary.utilizationPercent = tr.Budget_Utilization_Percent__c != null ? (tr.Budget_Utilization_Percent__c * 100).setScale(1) : 0.0;
        summary.status = tr.Status__c;

        // Fetch category breakdown
        Map<String, ExpenseCategorySpend> catMap = new Map<String, ExpenseCategorySpend>();
        Integer totalItems = 0;

        List<Expense_Item__c> items = [
            SELECT Id, Expense_Category__c, Amount__c
            FROM Expense_Item__c
            WHERE Expense_Report__r.Travel_Request__c = :travelRequestId
        ];

        for (Expense_Item__c itm : items) {
            totalItems++;
            String cat = String.isNotBlank(itm.Expense_Category__c) ? itm.Expense_Category__c : 'Other';
            if (!catMap.containsKey(cat)) {
                ExpenseCategorySpend cs = new ExpenseCategorySpend();
                cs.category = cat;
                cs.totalAmount = 0.00;
                cs.itemCount = 0;
                catMap.put(cat, cs);
            }
            ExpenseCategorySpend cs = catMap.get(cat);
            cs.totalAmount += (itm.Amount__c != null ? itm.Amount__c : 0.00);
            cs.itemCount += 1;
        }

        summary.totalExpenseItems = totalItems;
        summary.categoryBreakdown = catMap.values();

        // Count open exceptions
        Integer openExceptions = [
            SELECT count()
            FROM Expense_Validation_Exception__c
            WHERE Travel_Request__c = :travelRequestId AND Status__c = 'Open'
        ];
        summary.openExceptionCount = openExceptions;

        return summary;
    }

    @AuraEnabled(cacheable=true)
    public static List<ExpenseItemDTO> getExpenseItems(Id travelRequestId) {
        if (travelRequestId == null) {
            return new List<ExpenseItemDTO>();
        }

        List<Expense_Item__c> items = [
            SELECT Id, Name, Expense_Category__c, Amount__c, Expense_Date__c,
                   Vendor__c, Validation_Status__c, Policy_Result__c,
                   Receipt_Attached__c, Exception_Reason__c, Is_Duplicate_Flag__c
            FROM Expense_Item__c
            WHERE Expense_Report__r.Travel_Request__c = :travelRequestId
            ORDER BY Expense_Date__c DESC, CreatedDate DESC
            LIMIT 200
        ];

        List<ExpenseItemDTO> dtos = new List<ExpenseItemDTO>();
        for (Expense_Item__c itm : items) {
            ExpenseItemDTO dto = new ExpenseItemDTO();
            dto.id = itm.Id;
            dto.name = itm.Name;
            dto.category = itm.Expense_Category__c;
            dto.amount = itm.Amount__c;
            dto.expenseDate = itm.Expense_Date__c;
            dto.vendor = itm.Vendor__c;
            dto.validationStatus = itm.Validation_Status__c;
            dto.policyResult = itm.Policy_Result__c;
            dto.receiptAttached = itm.Receipt_Attached__c;
            dto.exceptionReason = itm.Exception_Reason__c;
            dto.isDuplicate = itm.Is_Duplicate_Flag__c;
            dtos.add(dto);
        }
        return dtos;
    }

    @AuraEnabled
    public static Id submitQuickExpense(
        Id travelRequestId,
        String category,
        Decimal amount,
        Date expenseDate,
        String vendor,
        String description,
        Boolean receiptAttached
    ) {
        if (travelRequestId == null) {
            throw new AuraHandledException('Travel Request ID is required.');
        }
        if (amount == null || amount <= 0) {
            throw new AuraHandledException('Expense Amount must be greater than zero.');
        }

        // Find or create an open Expense Report for this Travel Request
        List<Expense_Report__c> openReports = [
            SELECT Id
            FROM Expense_Report__c
            WHERE Travel_Request__c = :travelRequestId AND Status__c IN ('Draft', 'Pending Validation')
            LIMIT 1
        ];

        Id reportId;
        if (!openReports.isEmpty()) {
            reportId = openReports[0].Id;
        } else {
            Expense_Report__c newRep = new Expense_Report__c(
                Travel_Request__c = travelRequestId,
                Employee__c = UserInfo.getUserId(),
                Report_Date__c = Date.today(),
                Status__c = 'Draft',
                Comments__c = 'Quick-entry expense report created from Trip Wallet.'
            );
            insert newRep;
            reportId = newRep.Id;
        }

        Expense_Item__c newItem = new Expense_Item__c(
            Expense_Report__c = reportId,
            Expense_Category__c = category,
            Amount__c = amount,
            Expense_Date__c = expenseDate != null ? expenseDate : Date.today(),
            Vendor__c = vendor,
            Description__c = description,
            Paid_By__c = 'Personal Cash / Card',
            Receipt_Attached__c = receiptAttached != null ? receiptAttached : false
        );
        insert newItem;

        return newItem.Id;
    }
}
