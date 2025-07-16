@isTest
private class DataDictionaryObjects_Batch_Test {

    @TestSetup
    static void makeData() {
        // Create an outdated record for the update test.
        // We are changing Label_Plural__c because the batch code DOES check this field.
        insert new Data_Object__c(Name = 'Contact', Label_Plural__c = 'Old Plural Label');
        
        // Create an obsolete record for the delete test.
        insert new Data_Object__c(Name = 'ObsoleteObject__c');
    }

    @isTest
    static void testBatchCreatePath() {
        // This test verifies the "create" path for the Account object.
        Test.startTest();
        // The batch's start() method returns {Account, Contact} in a test.
        Database.executeBatch(new DataDictionaryObjects_Batch());
        Test.stopTest();

        // Assert that the Data_Object__c for Account was created.
        List<Data_Object__c> createdObjects = [SELECT Name FROM Data_Object__c WHERE Name = 'Account'];
        System.assertEquals(1, createdObjects.size(), 'A Data_Object__c record for Account should have been created.');
    }
    
    @isTest
    static void testBatchUpdatePath() {
        // This test verifies the "update" path for the Contact object created in @TestSetup.
        Test.startTest();
        // The constructor finds the 'Contact' record from setup. The execute() method will
        // find that its Label_Plural__c is different from the schema and update it.
        Database.executeBatch(new DataDictionaryObjects_Batch());
        Test.stopTest();
        
        // Assert the 'Contact' record's Label_Plural__c was updated.
        Data_Object__c updatedObject = [SELECT Label_Plural__c FROM Data_Object__c WHERE Name = 'Contact'];
        System.assertEquals('Contacts', updatedObject.Label_Plural__c, 'The plural label for Contact should have been updated.');
    }

    @isTest
    static void testBatchDeletePath() {
        // This test verifies that an obsolete record is deleted by the finish() method.
        Test.startTest();
        // The constructor finds 'ObsoleteObject__c'. The execute() method runs for {Account, Contact},
        // leaving the obsolete record in the stateful map to be deleted by finish().
        Database.executeBatch(new DataDictionaryObjects_Batch());
        Test.stopTest();
        
        // Assert the obsolete record was deleted.
        List<Data_Object__c> shouldBeDeleted = [SELECT Id FROM Data_Object__c WHERE Name = 'ObsoleteObject__c'];
        System.assertEquals(0, shouldBeDeleted.size(), 'The obsolete Data_Object__c should have been deleted.');
    }
}