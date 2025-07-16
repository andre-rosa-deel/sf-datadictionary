@isTest
private class DataDictionaryFields_Batch_Test {

    @TestSetup
    static void makeData() {
        // Create the parent Data Object record, a prerequisite for all test paths.
        insert new Data_Object__c(Name = 'Account', Label__c = 'Account');
    }

    @isTest
    static void testExecute_CreatePath() {
        // Verifies that the execute method correctly creates new Data_Field__c records.
        
        // 1. Setup
        DataDictionaryFields_Batch batch = new DataDictionaryFields_Batch();
        List<SObjectType> scope = new List<SObjectType>{ Account.sObjectType };

        // 2. Action: Call the execute method directly.
        Test.startTest();
        batch.execute(null, scope);
        Test.stopTest();

        // 3. Assert
        Map<String, Data_Field__c> fields = new Map<String, Data_Field__c>();
        for(Data_Field__c f : [SELECT Name, Label__c FROM Data_Field__c WHERE Data_Object__r.Name = 'Account']) {
            fields.put(f.Name, f);
        }
        System.assert(fields.containsKey('Name'), 'A Data_Field__c for Account Name should have been created.');
        System.assertEquals('Account Name', fields.get('Name').Label__c, 'The label for the Name field should match the schema.');
    }

    @isTest
    static void testExecute_UpdatePath() {
        // Verifies that the execute method correctly updates an existing record.
        
        // 1. Setup: Create an outdated record.
        Data_Object__c parentObject = [SELECT Id FROM Data_Object__c WHERE Name = 'Account' LIMIT 1];
        insert new Data_Field__c(Name = 'Fax', Data_Object__c = parentObject.Id, Label__c = 'Old Incorrect Fax Label');

        // 2. Action: Call the execute method directly.
        DataDictionaryFields_Batch batch = new DataDictionaryFields_Batch();
        List<SObjectType> scope = new List<SObjectType>{ Account.sObjectType };
        Test.startTest();
        batch.execute(null, scope);
        Test.stopTest();
        
        // 3. Assert: Verify the record was updated with the correct schema label.
        Data_Field__c updatedField = [SELECT Label__c FROM Data_Field__c WHERE Name = 'Fax'];
        // Corrected Assertion: The test log shows the actual label is 'Account Fax'.
        System.assertEquals('Account Fax', updatedField.Label__c, 'The label for the Fax field should have been corrected.');
    }

    @isTest
    static void testExecute_SoftDeletePath() {
        // Verifies that the execute method correctly soft-deletes an obsolete record.
        
        // 1. Setup: Create an obsolete field record.
        Data_Object__c parentObject = [SELECT Id FROM Data_Object__c WHERE Name = 'Account' LIMIT 1];
        insert new Data_Field__c(Name = 'ObsoleteField__c', Data_Object__c = parentObject.Id, Deleted__c = false);
        
        // 2. Action: Call the execute method directly.
        DataDictionaryFields_Batch batch = new DataDictionaryFields_Batch();
        List<SObjectType> scope = new List<SObjectType>{ Account.sObjectType };
        Test.startTest();
        batch.execute(null, scope);
        Test.stopTest();

        // 3. Assert: Verify the record was marked as deleted.
        Data_Field__c softDeletedField = [SELECT Deleted__c FROM Data_Field__c WHERE Name = 'ObsoleteField__c'];
        System.assert(softDeletedField.Deleted__c, 'The Deleted__c flag should be true for the obsolete field.');
    }
}