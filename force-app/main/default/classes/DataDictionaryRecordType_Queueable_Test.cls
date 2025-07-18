@isTest
private class DataDictionaryRecordType_Queueable_Test {

    @TestSetup
    static void makeData() {
        // PROACTIVE SETUP: Dynamically create a parent Data_Object__c for every
        // SObject in the org that has at least one RecordType.
        Set<String> objectNamesWithRecordTypes = new Set<String>();
        for (RecordType rt : [SELECT SobjectType FROM RecordType]) {
            objectNamesWithRecordTypes.add(rt.SobjectType);
        }

        List<Data_Object__c> prerequisiteObjects = new List<Data_Object__c>();
        for (String objName : objectNamesWithRecordTypes) {
            prerequisiteObjects.add(new Data_Object__c(Name = objName, Label__c = objName));
        }
        
        if (!prerequisiteObjects.isEmpty()) {
            insert prerequisiteObjects;
        }
    }

    @isTest
    static void testExecute_CreatePath() {
        // Verifies the "create" path.
        Test.startTest();
        System.enqueueJob(new DataDictionaryRecordType_Queueable());
        Test.stopTest();

        List<RecordType> allRts = [SELECT Id FROM RecordType];
        List<Data_Object_Record_Type__c> createdDORTs = [SELECT Id FROM Data_Object_Record_Type__c];
        
        System.assertEquals(allRts.size(), createdDORTs.size(), 'A DORT record should be created for each existing RecordType.');
    }

    @isTest
    static void testExecute_UpdatePath() {
        // Verifies the "update" path.
        RecordType rt = [SELECT Id, DeveloperName FROM RecordType WHERE SobjectType = 'Account' AND IsActive = true LIMIT 1];
        System.assertNotEquals(null, rt, 'Test requires an active Account record type.');
        Data_Object__c parentObj = [SELECT Id FROM Data_Object__c WHERE Name = 'Account' LIMIT 1];
        
        insert new Data_Object_Record_Type__c(
            Data_Object__c = parentObj.Id,
            Record_Type_Id__c = rt.Id,
            Developer_Name__c = 'Outdated_Developer_Name'
        );

        Test.startTest();
        System.enqueueJob(new DataDictionaryRecordType_Queueable());
        Test.stopTest();
        
        Data_Object_Record_Type__c updatedRecord = [SELECT Developer_Name__c FROM Data_Object_Record_Type__c WHERE Record_Type_Id__c = :rt.Id];
        System.assertEquals(rt.DeveloperName, updatedRecord.Developer_Name__c, 'The Developer Name should have been updated.');
    }
    
    @isTest
    static void testExecute_DeletePath() {
        // Verifies the "delete" path.
        Data_Object__c parentObj = [SELECT Id FROM Data_Object__c WHERE Name = 'Account' LIMIT 1];
        insert new Data_Object_Record_Type__c(
            Data_Object__c = parentObj.Id,
            Record_Type_Id__c = '012000000000000AAA' // Fake Id
        );
        
        Test.startTest();
        System.enqueueJob(new DataDictionaryRecordType_Queueable());
        Test.stopTest();
        
        List<Data_Object_Record_Type__c> shouldBeDeleted = [SELECT Id FROM Data_Object_Record_Type__c WHERE Record_Type_Id__c = '012000000000000AAA'];
        System.assertEquals(0, shouldBeDeleted.size(), 'The obsolete DORT record should have been deleted.');
    }
}