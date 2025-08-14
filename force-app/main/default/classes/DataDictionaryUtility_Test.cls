@IsTest
private class DataDictionaryUtility_Test {
    @IsTest
    static void testCreateNewDataField_WithFieldDefinition() {
        Schema.DescribeFieldResult dfr = Account.Name.getDescribe();

        // Corrected Query: Included every field accessed by the createNewDataField method.
        FieldDefinition fd = [
            SELECT
                DurableId,
                QualifiedApiName,
                EntityDefinitionId,
                NamespacePrefix,
                Label,
                Length,
                DataType,
                ExtraTypeInfo,
                IsCalculated,
                IsHighScaleNumber,
                IsHtmlFormatted,
                IsNameField,
                IsNillable,
                IsWorkflowFilterable,
                IsCompactLayoutable,
                Precision,
                Scale,
                IsFieldHistoryTracked,
                IsIndexed,
                IsApiFilterable,
                IsApiSortable,
                IsListFilterable,
                IsListSortable,
                IsApiGroupable,
                IsListVisible,
                ControllingFieldDefinitionId,
                LastModifiedDate,
                LastModifiedById,
                RelationshipName,
                IsCompound,
                IsSearchPrefilterable,
                IsPolymorphicForeignKey,
                BusinessOwnerId,
                BusinessStatus,
                SecurityClassification,
                Description
            FROM FieldDefinition
            WHERE
                EntityDefinition.QualifiedApiName = 'Account'
                AND QualifiedApiName = 'Name'
            LIMIT 1
        ];

        // Test the method
        Data_Field__c resultField = DataDictionaryUtility.createNewDataField(
            fd,
            dfr
        );

        // Assert that a key field was populated to confirm success
        Assert.isNotNull(
            resultField,
            'Resulting Data_Field__c should not be null.'
        );
        Assert.areEqual(
            fd.DurableId,
            resultField.Durable_Id__c,
            'DurableId should be populated.'
        );
        Assert.areEqual(
            fd.ExtraTypeInfo,
            resultField.Extra_Type_Info__c,
            'ExtraTypeInfo should now be populated.'
        );
    }

    @IsTest
    static void testCreateNewDataField_FromDescribeOnly() {
        // Use a standard field to avoid org-specific setup
        Schema.DescribeFieldResult dfr = Account.Name.getDescribe();

        Data_Field__c result = DataDictionaryUtility.createNewDataField(
            null,
            dfr
        );

        // Assertions using Salesforce Assert class
        Assert.areEqual(
            dfr.getName(),
            result.Name,
            'Name should come from describe.'
        );
        Assert.areEqual(
            dfr.getName(),
            result.Name__c,
            'Name__c should mirror describe name.'
        );
        Assert.areEqual(
            dfr.getLength(),
            result.Length__c,
            'Length should map from describe.'
        );
        Assert.areEqual(
            String.valueOf(dfr.getType()),
            result.Type__c,
            'Type__c should match describe type.'
        );
        Assert.areEqual(
            String.valueOf(dfr.getSObjectField()),
            result.SObject_Field__c,
            'SObject_Field__c should stringify the field token.'
        );
        Assert.areEqual(
            dfr.getByteLength(),
            result.Byte_Length__c,
            'Byte length should map from describe.'
        );
        // Non-picklist => no values expected
        Assert.isNull(
            result.Picklist_Values__c,
            'Non-picklist fields should not produce picklist values.'
        );
    }

    @IsTest
    static void testCreateNewDataField_WithIds() {
        Schema.DescribeFieldResult dfr = Account.Name.getDescribe();
        Id someExistingFieldId = IDGenerator.generate(
            Data_Field__c.sObjectType
        );
        Id someExistingObjectId = IDGenerator.generate(
            Data_Object__c.sObjectType
        );

        Data_Field__c result = DataDictionaryUtility.createNewDataField(
            null,
            dfr,
            someExistingFieldId, // dataFieldId
            someExistingObjectId // dataObjectId
        );

        Assert.areEqual(
            someExistingFieldId,
            result.Id,
            'Id should be set on the returned sObject.'
        );
        Assert.areEqual(
            someExistingObjectId,
            result.Data_Object__c,
            'Data_Object__c should be assigned.'
        );
    }

    @IsTest
    static void testGetPicklistValues() {
        // Standard picklist
        Schema.DescribeFieldResult statusDfr = Lead.Status.getDescribe();
        List<Schema.PicklistEntry> entries = statusDfr.getPicklistValues();

        String joined = DataDictionaryUtility.getPicklistValues(entries);

        Assert.isNotNull(joined, 'Joined picklist string should not be null.');
        Assert.isTrue(
            joined.contains(','),
            'Joined picklist should be comma-separated.'
        );
        Assert.isTrue(
            joined.length() <= 131000,
            'Joined picklist should be abbreviated to the cap.'
        );
    }

    @IsTest
    static void testDataDictionaryFieldsMatching_trueThenFalse() {
        // Build two identical in-memory records (no DML)
        Data_Field__c a = new Data_Field__c();
        a.Name = 'Field__c';
        a.Length__c = 42;
        a.Type__c = 'Text';
        a.Data_Type__c = 'Text';
        a.Label__c = 'Field';

        Data_Field__c b = a.clone();

        List<String> tracked = new List<String>{
            'Name',
            'Length__c',
            'Type__c',
            'Data_Type__c',
            'Label__c'
        };

        // Should match
        Boolean match = DataDictionaryUtility.dataDictionaryFieldsMatching(
            a,
            b,
            tracked
        );
        Assert.isTrue(match, 'Identical fields should match.');

        // Change one value => mismatch
        b.Label__c = 'Changed';
        Boolean mismatch = DataDictionaryUtility.dataDictionaryFieldsMatching(
            a,
            b,
            tracked
        );
        Assert.isFalse(mismatch, 'Different fields should not match.');
    }

    @IsTest
    static void testDataFieldsInScope_emptyInput() {
        // No record types passed => wrapper should be returned with empty maps/sets
        DataDictionaryObjects.DataFieldScopeWrapper w = DataDictionaryUtility.dataFieldsInScope(
            new List<RecordType>()
        );

        Assert.isNotNull(w, 'Wrapper should not be null.');
        Assert.isNotNull(w.dataFieldsIdMap, 'Map should be initialized.');
        Assert.isNotNull(
            w.ScopeRecordTypeIdSet,
            'RecordType set should be initialized.'
        );
        Assert.areEqual(
            0,
            w.dataFieldsIdMap.size(),
            'Map should be empty for empty scope.'
        );
        Assert.areEqual(
            0,
            w.ScopeRecordTypeIdSet.size(),
            'Set should be empty for empty scope.'
        );
    }

    @IsTest
    static void testSubmitDataObjectBatch_returnIds() {
        Test.startTest();
        Id objBatchId = DataDictionaryUtility.submitDataObjectBatch();
        Test.stopTest();

        Assert.isNotNull(
            objBatchId,
            'submitDataObjectBatch should return a job Id.'
        );
    }

    @IsTest
    static void testSubmitDataPicklistBatch_returnIds() {
        Test.startTest();
        Id pickBatchId = DataDictionaryUtility.submitDataPicklistBatch();
        Test.stopTest();

        Assert.isNotNull(
            pickBatchId,
            'submitDataPicklistBatch should return a job Id.'
        );
    }

    @IsTest
    static void testSubmitMetadataReferencesBatch_returnIds() {
        Test.startTest();
        Id refsBatchId = DataDictionaryUtility.submitMetadataReferencesBatch();
        Test.stopTest();

        Assert.isNotNull(
            refsBatchId,
            'submitMetadataReferencesBatch should return a job Id.'
        );
    }
}
