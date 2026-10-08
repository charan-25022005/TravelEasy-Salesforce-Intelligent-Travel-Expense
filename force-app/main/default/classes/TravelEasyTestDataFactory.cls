@IsTest
public class TravelEasyTestDataFactory {

    public static Travel_Request__c createTravelRequest(Id employeeId, String dest, Decimal estCost) {
        Travel_Request__c tr = new Travel_Request__c(
            Employee__c = employeeId != null ? employeeId : UserInfo.getUserId(),
            Destination__c = dest,
            Purpose__c = 'Client Strategy & Architecture Review',
            Start_Date__c = Date.today().addDays(7),
            End_Date__c = Date.today().addDays(10),
            Travel_Type__c = 'Client Visit',
            Department__c = 'Engineering',
            Estimated_Cost__c = estCost,
            Status__c = 'Draft',
            Approval_Status__c = 'Pending',
            Business_Justification__c = 'Critical onsite alignment with enterprise stakeholders.'
        );
        insert tr;
        return tr;
    }

    public static Expense_Report__c createExpenseReport(Id travelRequestId, Id employeeId) {
        Expense_Report__c er = new Expense_Report__c(
            Travel_Request__c = travelRequestId,
            Employee__c = employeeId != null ? employeeId : UserInfo.getUserId(),
            Report_Date__c = Date.today(),
            Status__c = 'Draft',
            Validation_Status__c = 'Pending Validation',
            Approval_Status__c = 'Pending',
            Reimbursement_Status__c = 'Not Applicable',
            Comments__c = 'Quarterly onsite travel expenses.'
        );
        insert er;
        return er;
    }

    public static Expense_Item__c createExpenseItem(Id reportId, String category, Decimal amount, Boolean receiptAttached) {
        Expense_Item__c item = new Expense_Item__c(
            Expense_Report__c = reportId,
            Expense_Category__c = category,
            Amount__c = amount,
            Expense_Date__c = Date.today(),
            Vendor__c = 'Acme Services',
            Description__c = 'Travel expense for ' + category,
            Paid_By__c = 'Personal Cash / Card',
            Participants_Count__c = 1,
            Reimbursable_Amount__c = amount,
            Receipt_Attached__c = receiptAttached,
            Validation_Status__c = 'Not Evaluated'
        );
        insert item;
        return item;
    }

    public static List<Expense_Item__c> createMultipleExpenseItems(Id reportId, Integer count, String category, Decimal amount) {
        List<Expense_Item__c> items = new List<Expense_Item__c>();
        for (Integer i = 0; i < count; i++) {
            items.add(new Expense_Item__c(
                Expense_Report__c = reportId,
                Expense_Category__c = category,
                Amount__c = amount,
                Expense_Date__c = Date.today().addDays(-i),
                Vendor__c = 'Vendor ' + i,
                Description__c = 'Bulk test expense ' + i,
                Paid_By__c = 'Personal Cash / Card',
                Participants_Count__c = 1,
                Reimbursable_Amount__c = amount,
                Receipt_Attached__c = true,
                Validation_Status__c = 'Not Evaluated'
            ));
        }
        insert items;
        return items;
    }
}
