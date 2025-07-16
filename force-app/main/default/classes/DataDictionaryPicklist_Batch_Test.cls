@isTest
private class DataDictionaryPicklist_Batch_Test {

    @TestSetup
    static void makeData() {
        // 1. Create parent Data Object
        Data_Object__c dataObject = new Data_Object__c(Name = 'Account');
        insert dataObject;
        
        // 2. Create parent Data Field for a picklist
        insert new Data_Field__c(
            Name = 'Industry', 
            Data_Object__c = dataObject.Id, 
            Type__c = 'PICKLIST'
        );
        
        // 3. Proactive Setup: Create a parent Data_Object_Record_Type__c for
        //    EVERY active Account RecordType to prevent lookup errors in the batch.
        List<RecordType> accountRecordTypes = [SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND IsActive = true];
        System.assert(!accountRecordTypes.isEmpty(), 'Test requires at least one active Account record type.');
        
        List<Data_Object_Record_Type__c> DORTsToCreate = new List<Data_Object_Record_Type__c>();
        for (RecordType rt : accountRecordTypes) {
            DORTsToCreate.add(new Data_Object_Record_Type__c(
                Name = 'Test RT ' + rt.Id,
                Data_Object__c = dataObject.Id,
                Record_Type_Id__c = rt.Id
            ));
        }
        insert DORTsToCreate;
    }
    
    @isTest
    static void testExecute_SuccessPath() {
        // 1. Setup
        // Define a mock JSON response for a successful API call.
        String mockSuccessBody = '{' +
            '"picklistFieldValues": {' +
            '    "Industry": {' +
            '        "values": [' +
            '            {"label": "Agriculture", "value": "Agriculture"},' +
            '            {"label": "Banking", "value": "Banking"}' +
            '        ]' +
            '    }' +
            '}' +
        '}';
        Test.setMock(HttpCalloutMock.class, new DataDictionaryCalloutMock(200, 'OK', mockSuccessBody));
        
        DataDictionaryPicklist_Batch batch = new DataDictionaryPicklist_Batch();
        List<RecordType> scope = [SELECT Id, SobjectType FROM RecordType WHERE SobjectType = 'Account' AND IsActive = true];

        // 2. Action: Call the execute method directly.
        Test.startTest();
        batch.execute(null, scope);
        Test.stopTest();
        
        // 3. Assert
        // The number of picklist records created should be (number of RTs in scope) * (number of mock picklist values)
        Integer expectedCount = scope.size() * 2;
        List<Data_Field_Record_Type_Picklist__c> picklists = [SELECT Id FROM Data_Field_Record_Type_Picklist__c];
        System.assertEquals(expectedCount, picklists.size(), 'The correct number of picklist records should have been created.');
    }
    
    @isTest
    static void testExecute_CalloutFailurePath() {
        // 1. Setup
        Test.setMock(HttpCalloutMock.class, new DataDictionaryCalloutMock(500, 'Server Error', ''));
        
        DataDictionaryPicklist_Batch batch = new DataDictionaryPicklist_Batch();
        List<RecordType> scope = [SELECT Id, SobjectType FROM RecordType WHERE SobjectType = 'Account' AND IsActive = true];

        // 2. Action
        Test.startTest();
        batch.execute(null, scope);
        Test.stopTest();
        
        // 3. Assert
        List<Data_Field_Record_Type_Picklist__c> picklists = [SELECT Id FROM Data_Field_Record_Type_Picklist__c];
        System.assertEquals(0, picklists.size(), 'No records should be created when the callout fails.');
    }
}