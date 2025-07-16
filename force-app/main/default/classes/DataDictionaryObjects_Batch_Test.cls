@isTest
private class DataDictionaryObjects_Batch_Test {

    @isTest
    static void testBatchCreatePath() {
        // This test verifies the "create" path. No data setup is needed
        // as the test org is empty and the batch will create the record.
        Test.startTest();
        // The batch's start() method returns {Account, Contact} in a test.
        // The execute() method will create a new Data_Object__c for Account.
        Database.executeBatch(new DataDictionaryObjects_Batch());
        Test.stopTest();

        // Assert that the Data_Object__c for Account was created.
        List<Data_Object__c> createdObjects = [SELECT Id, Name FROM Data_Object__c WHERE Name = 'Account'];
        System.assertEquals(1, createdObjects.size(), 'A Data_Object__c record for Account should have been created.');
    }
    
    @isTest
    static void testBatchUpdatePath() {
        // This test verifies the "update" path using the Contact object to ensure isolation.
        
        // 1. Setup: Create an outdated record for 'Contact'.
        insert new Data_Object__c(Name = 'Contact', Label__c = 'Old Contact Label');

        Test.startTest();
        // The constructor will find the 'Contact' record.
        // The execute() method will identify it as outdated and update it.
        Database.executeBatch(new DataDictionaryObjects_Batch());
        Test.stopTest();
        
        // 2. Assert: Verify the 'Contact' record was updated.
        Data_Object__c updatedObject = [SELECT Id, Label__c FROM Data_Object__c WHERE Name = 'Contact'];
        System.assertEquals('Contact', updatedObject.Label__c, 'The label for Contact should have been updated.');
        // Ensure no duplicates were created.
        System.assertEquals(1, [SELECT COUNT() FROM Data_Object__c WHERE Name = 'Contact'], 'There should only be one Contact Data_Object record.');
    }

    @isTest
    static void testBatchDeletePath() {
        // This test verifies that an obsolete record is deleted by the finish() method.
        
        // 1. Setup: Create a record for an object that doesn't exist in the test scope.
        insert new Data_Object__c(Name = 'ObsoleteObject__c');

        Test.startTest();
        // The constructor finds 'ObsoleteObject__c' and adds it to the stateful map.
        // The execute() method processes 'Account' and 'Contact', but leaves 'ObsoleteObject__c' in the map.
        // The finish() method will now correctly delete what remains.
        Database.executeBatch(new DataDictionaryObjects_Batch());
        Test.stopTest();
        
        // 2. Assert: Verify the obsolete record was deleted.
        List<Data_Object__c> shouldBeDeleted = [SELECT Id FROM Data_Object__c WHERE Name = 'ObsoleteObject__c'];
        System.assertEquals(0, shouldBeDeleted.size(), 'The obsolete Data_Object__c should have been deleted by the finish() method.');
    }
}