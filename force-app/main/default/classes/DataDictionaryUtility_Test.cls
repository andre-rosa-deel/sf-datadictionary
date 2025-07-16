@isTest
private class DataDictionaryUtility_Test {

    @TestSetup
    static void makeData() {
        Data_Object__c obj = new Data_Object__c(Name = 'Account', Label__c = 'Account');
        insert obj;
    }

    @isTest
    static void testCreateNewDataField_WithFieldDefinition() {
        Schema.DescribeFieldResult dfr = Account.Name.getDescribe();
        
        // Corrected Query: Included every field accessed by the createNewDataField method.
        FieldDefinition fd = [
            SELECT DurableId, QualifiedApiName, EntityDefinitionId, NamespacePrefix, Label, Length, DataType, 
                   ExtraTypeInfo, IsCalculated, IsHighScaleNumber, IsHtmlFormatted, IsNameField, IsNillable, 
                   IsWorkflowFilterable, IsCompactLayoutable, Precision, Scale, IsFieldHistoryTracked, IsIndexed, 
                   IsApiFilterable, IsApiSortable, IsListFilterable, IsListSortable, IsApiGroupable, IsListVisible, 
                   ControllingFieldDefinitionId, LastModifiedDate, LastModifiedById, RelationshipName, IsCompound, 
                   IsSearchPrefilterable, IsPolymorphicForeignKey, BusinessOwnerId, BusinessStatus, 
                   SecurityClassification, Description 
            FROM FieldDefinition 
            WHERE EntityDefinition.QualifiedApiName = 'Account' 
            AND QualifiedApiName = 'Name' 
            LIMIT 1
        ];

        // Test the method
        Data_Field__c resultField = DataDictionaryUtility.createNewDataField(fd, dfr);

        // Assert that a key field was populated to confirm success
        System.assertNotEquals(null, resultField, 'Resulting Data_Field__c should not be null.');
        System.assertEquals(fd.DurableId, resultField.Durable_Id__c, 'DurableId should be populated.');
        System.assertEquals(fd.ExtraTypeInfo, resultField.Extra_Type_Info__c, 'ExtraTypeInfo should now be populated.');
    }
    
    @isTest
    static void testCreateNewDataField_WithoutFieldDefinition() {
        Schema.DescribeFieldResult dfr = Account.Phone.getDescribe();
        Data_Field__c resultField = DataDictionaryUtility.createNewDataField(null, dfr);
        System.assertNotEquals(null, resultField, 'Resulting Data_Field__c should not be null.');
        System.assertEquals('Phone', resultField.Name, 'Name should be populated from describe result.');
    }

    @isTest
    static void testGetPicklistValues() {
        Schema.DescribeFieldResult dfr = Account.Industry.getDescribe();
        String picklistString = DataDictionaryUtility.getPicklistValues(dfr.getPicklistValues());
        System.assertNotEquals(null, picklistString, 'Picklist string should not be null.');
    }

    @isTest
    static void testDataDictionaryFieldsMatching() {
        Data_Object__c testObject = [SELECT Id FROM Data_Object__c WHERE Name = 'Account'];
        List<String> trackedFields = new List<String>{'Label__c'};
        Data_Field__c field1 = new Data_Field__c(Data_Object__c = testObject.Id, Label__c = 'Test Label');
        Data_Field__c field2 = new Data_Field__c(Data_Object__c = testObject.Id, Label__c = 'Test Label');
        System.assert(DataDictionaryUtility.dataDictionaryFieldsMatching(field1, field2, trackedFields), 'Identical fields should match.');
        field2.Label__c = 'A Different Label';
        System.assert(!DataDictionaryUtility.dataDictionaryFieldsMatching(field1, field2, trackedFields), 'Different fields should not match.');
    }
}