System.debug('====================================================');
System.debug('STARTING TRAVELEASY END-TO-END BUSINESS VALIDATION');
System.debug('Target Org: ' + UserInfo.getUserName() + ' (' + UserInfo.getOrganizationId() + ')');
System.debug('====================================================');

// =========================================================================
// SCENARIO 1: NORMAL BUSINESS JOURNEY (HAPPY PATH)
// =========================================================================
System.debug('--- SCENARIO 1: CREATING TRAVEL REQUEST (CHENNAI -> BANGALORE) ---');
Travel_Request__c tr1 = new Travel_Request__c(
    Employee__c = UserInfo.getUserId(),
    Destination__c = 'Bangalore',
    Purpose__c = 'Enterprise Client Architectural Review',
    Start_Date__c = Date.today().addDays(5),
    End_Date__c = Date.today().addDays(8),
    Travel_Type__c = 'Client Visit',
    Department__c = 'Engineering',
    Estimated_Cost__c = 25000,
    Status__c = 'Draft',
    Business_Justification__c = 'Executive alignment meeting and platform architecture workshop.'
);
insert tr1;
System.debug('Created Travel Request: ' + tr1.Id);

// Manager Approves Travel Request
tr1.Status__c = 'Under Approval';
tr1.Approval_Status__c = 'Approved';
update tr1;
System.debug('Travel Request Approved successfully.');

// Employee Submits Expense Report
Expense_Report__c er1 = new Expense_Report__c(
    Travel_Request__c = tr1.Id,
    Employee__c = UserInfo.getUserId(),
    Report_Date__c = Date.today(),
    Status__c = 'Draft',
    Comments__c = 'Onsite Bangalore client engagement expenses.'
);
insert er1;
System.debug('Created Expense Report: ' + er1.Id);

// Add Normal Expense Items
List<Expense_Item__c> normalItems = new List<Expense_Item__c>{
    new Expense_Item__c(
        Expense_Report__c = er1.Id,
        Expense_Category__c = 'Airfare',
        Amount__c = 11500,
        Expense_Date__c = Date.today(),
        Vendor__c = 'IndiGo Airlines',
        Description__c = 'Economy flight tickets MAA-BLR round trip',
        Paid_By__c = 'Personal Cash / Card',
        Receipt_Attached__c = true
    ),
    new Expense_Item__c(
        Expense_Report__c = er1.Id,
        Expense_Category__c = 'Hotel / Lodging',
        Amount__c = 6500,
        Expense_Date__c = Date.today(),
        Vendor__c = 'Lemon Tree Premier',
        Description__c = '2 nights hotel lodging',
        Paid_By__c = 'Personal Cash / Card',
        Receipt_Attached__c = true
    ),
    new Expense_Item__c(
        Expense_Report__c = er1.Id,
        Expense_Category__c = 'Ground Transportation / Taxi',
        Amount__c = 1200,
        Expense_Date__c = Date.today(),
        Vendor__c = 'Uber India',
        Description__c = 'Airport transfers and client office transit',
        Paid_By__c = 'Personal Cash / Card',
        Receipt_Attached__c = true
    ),
    new Expense_Item__c(
        Expense_Report__c = er1.Id,
        Expense_Category__c = 'Meals & Food',
        Amount__c = 850,
        Expense_Date__c = Date.today(),
        Vendor__c = 'Barbeque Nation',
        Description__c = 'Dinner during business travel',
        Paid_By__c = 'Personal Cash / Card',
        Receipt_Attached__c = true
    )
};
insert normalItems;
System.debug('Inserted ' + normalItems.size() + ' normal expense items.');

// Validate Items evaluation
List<Expense_Item__c> evaluatedNormal = [
    SELECT Id, Name, Expense_Category__c, Amount__c, Validation_Status__c, Policy_Result__c
    FROM Expense_Item__c
    WHERE Expense_Report__c = :er1.Id
];
for (Expense_Item__c itm : evaluatedNormal) {
    System.debug('Item ' + itm.Name + ' [' + itm.Expense_Category__c + '] Amount: ' + itm.Amount__c + 
                 ' | Validation: ' + itm.Validation_Status__c + ' | Result: ' + itm.Policy_Result__c);
    System.assert(itm.Validation_Status__c == 'Passed', 'Normal expense should pass Smart Expense Control.');
}

// Approve Expense Report
update new Expense_Report__c(Id = er1.Id, Approval_Status__c = 'Approved');
System.debug('Expense Report approved.');

// Verify Reimbursement creation
List<Reimbursement__c> reimbursements = [
    SELECT Id, Name, Approved_Amount__c, Reimbursement_Status__c, Payment_Reference__c
    FROM Reimbursement__c
    WHERE Expense_Report__c = :er1.Id
];
System.assert(!reimbursements.isEmpty(), 'Reimbursement record must be generated automatically.');
System.debug('Reimbursement generated: ' + reimbursements[0].Name + ' | Amount: ₹' + reimbursements[0].Approved_Amount__c + ' | Status: ' + reimbursements[0].Reimbursement_Status__c);

// =========================================================================
// SCENARIO 2: SMART EXPENSE CONTROL EXCEPTION DETECTION & RESOLUTION
// =========================================================================
System.debug('--- SCENARIO 2: TESTING EXCEPTION ENGINE (POLICY VIOLATION & DUPLICATE) ---');
Travel_Request__c tr2 = new Travel_Request__c(
    Employee__c = UserInfo.getUserId(),
    Destination__c = 'Mumbai',
    Purpose__c = 'Partner Summit',
    Start_Date__c = Date.today().addDays(10),
    End_Date__c = Date.today().addDays(12),
    Travel_Type__c = 'Conference',
    Estimated_Cost__c = 15000,
    Status__c = 'Draft'
);
insert tr2;

Expense_Report__c er2 = new Expense_Report__c(
    Travel_Request__c = tr2.Id,
    Employee__c = UserInfo.getUserId(),
    Report_Date__c = Date.today(),
    Status__c = 'Draft',
    Comments__c = 'Exception demonstration report.'
);
insert er2;

// 1. Policy Limit Exception: Meals & Food for 3500 (limit is 2000)
Expense_Item__c policyExcItem = new Expense_Item__c(
    Expense_Report__c = er2.Id,
    Expense_Category__c = 'Meals & Food',
    Amount__c = 3500,
    Expense_Date__c = Date.today(),
    Vendor__c = 'Trident Dining',
    Description__c = 'Team dinner exceeding individual daily per-diem',
    Receipt_Attached__c = true
);
insert policyExcItem;

// 2. Missing Receipt Exception: Meals for 1200 without receipt
Expense_Item__c missingReceiptItem = new Expense_Item__c(
    Expense_Report__c = er2.Id,
    Expense_Category__c = 'Meals & Food',
    Amount__c = 1200,
    Expense_Date__c = Date.today(),
    Vendor__c = 'Cafe Coffee Day',
    Description__c = 'Snacks without bill',
    Receipt_Attached__c = false
);
insert missingReceiptItem;

// 3. Duplicate Expense: Identical vendor, amount, category, date
Expense_Item__c duplicateItem = new Expense_Item__c(
    Expense_Report__c = er2.Id,
    Expense_Category__c = 'Meals & Food',
    Amount__c = 3500,
    Expense_Date__c = Date.today(),
    Vendor__c = 'Trident Dining',
    Description__c = 'Duplicate charge submitted',
    Receipt_Attached__c = true
);
insert duplicateItem;

// Verify Exceptions
List<Expense_Validation_Exception__c> exceptions = [
    SELECT Id, Name, Exception_Type__c, Severity__c, Exception_Message__c, Status__c, Expense_Item__c
    FROM Expense_Validation_Exception__c
    WHERE Expense_Report__c = :er2.Id
];
System.debug('Exceptions flagged by Smart Expense Control: ' + exceptions.size());
for (Expense_Validation_Exception__c exc : exceptions) {
    System.debug('Exception ' + exc.Name + ' | Type: ' + exc.Exception_Type__c + ' | Severity: ' + exc.Severity__c + ' | Message: ' + exc.Exception_Message__c);
}
System.assert(exceptions.size() >= 3, 'Smart Expense Control must catch all 3 distinct policy exceptions.');

// Exception Resolution Workflow: Reviewer Approves with Justification
Expense_Validation_Exception__c excToResolve = exceptions[0];
excToResolve.Status__c = 'Resolved - Approved';
excToResolve.Action_Taken__c = 'Approved With Justification';
excToResolve.Reviewed_By__c = UserInfo.getUserId();
excToResolve.Review_Date__c = Datetime.now();
excToResolve.Resolution_Comments__c = 'Approved exception due to senior executive dining sponsorship.';
update excToResolve;
System.debug('Resolved Exception ' + excToResolve.Name + ' with justification.');

// Check parent report exception indicator
Expense_Report__c evaluatedEr2 = [
    SELECT Id, Has_Exceptions__c, Validation_Status__c
    FROM Expense_Report__c
    WHERE Id = :er2.Id
];
System.assertEquals(true, evaluatedEr2.Has_Exceptions__c, 'Parent report should show Has_Exceptions__c = true.');
System.assertEquals('Policy Exceptions Detected', evaluatedEr2.Validation_Status__c, 'Parent report status should reflect policy exceptions.');

System.debug('====================================================');
System.debug('TRAVELEASY E2E VALIDATION COMPLETED SUCCESSFULLY!');
System.debug('====================================================');
