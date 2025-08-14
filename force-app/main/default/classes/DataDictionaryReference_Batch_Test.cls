@IsTest
private class DataDictionaryReference_Batch_Test {
    @IsTest
    static void testBatch() {
        Data_Object__c obj = new Data_Object__c(
            Name = 'Object',
            Label__c = 'Object'
        );
        insert obj;

        // Arrange: create two data fields (only ones with Field_Id__c != null will be processed)
        Data_Field__c dfA = new Data_Field__c(
            Data_Object__c = obj.Id,
            Name = 'DF A',
            Custom__c = true,
            Durable_Id__c = 'Object.FieldA'
        );
        Data_Field__c dfB = new Data_Field__c(
            Data_Object__c = obj.Id,
            Name = 'DF B',
            Custom__c = true,
            Durable_Id__c = 'Object.FieldB'
        );
        insert new List<Data_Field__c>{ dfA, dfB };

        // Seed a stale existing reference that should be deleted by the batch
        Metadata_Component_Reference__c stale = new Metadata_Component_Reference__c(
            Data_Field__c = dfA.Id,
            Component_Id__c = 'MC_OLD_001',
            Component_Type__c = 'ApexClass',
            Component_Namespace__c = null,
            Component_Name__c = 'OldClass',
            External_Id__c = dfA.Field_Id__c + '|' + 'MC_OLD_001'
        );
        insert stale;

        // Prepare a single mocked HTTP response body. This same payload will be
        // returned for *each* field processed. The batch forms keys as:
        //   <Field_Id__c> + '|' + <MetadataComponentId>
        // So with two fields (FieldA, FieldB) and one component id (MC_001),
        // we expect two resulting references: FieldA|MC_001 and FieldB|MC_001.
        String mockBody =
            '{"records":[' +
            '{"MetadataComponentId":"MC_001",' +
            '"MetadataComponentType":"ApexClass",' +
            '"MetadataComponentNamespace":null,' +
            '"MetadataComponentName":"SomeClass"}' +
            ']}';

        // Use the provided mock class
        Test.setMock(
            HttpCalloutMock.class,
            new DataDictionaryCalloutMock(200, 'OK', mockBody)
        );

        // Act
        Test.startTest();
        // Small scope size to exercise multiple execute invocations is fine
        Database.executeBatch(new DataDictionaryReference_Batch(), 100);
        Test.stopTest();

        // Assert
        // Expect: two upserted references (FieldA|MC_001 and FieldB|MC_001)
        // and the stale (FieldA|MC_OLD_001) deleted.
        List<Metadata_Component_Reference__c> refs = [
            SELECT
                Id,
                External_Id__c,
                Data_Field__c,
                Component_Id__c,
                Component_Name__c
            FROM Metadata_Component_Reference__c
            ORDER BY External_Id__c
        ];

        System.assertEquals(
            2,
            refs.size(),
            'Exactly two references should exist after batch runs.'
        );

        Set<String> keys = new Set<String>();
        for (Metadata_Component_Reference__c r : refs)
            keys.add(r.External_Id__c);

        String expectedA = 'FieldA|MC_001';
        String expectedB = 'FieldB|MC_001';
        String staleKey = 'FieldA|MC_OLD_001';

        Assert.isTrue(
            keys.contains(expectedA),
            'Reference for FieldA must be upserted with MC_001.'
        );
        Assert.isTrue(
            keys.contains(expectedB),
            'Reference for FieldB must be upserted with MC_001.'
        );
        Assert.isTrue(
            !keys.contains(staleKey),
            'Stale reference must be deleted.'
        );

        // Spot-check component fields came from mock
        Map<String, Metadata_Component_Reference__c> byKey = new Map<String, Metadata_Component_Reference__c>();
        for (Metadata_Component_Reference__c r : refs)
            byKey.put(r.External_Id__c, r);

        Assert.areEqual(
            'MC_001',
            byKey.get(expectedA).Component_Id__c,
            'Component_Id__c for FieldA should match the mock.'
        );
        Assert.areEqual(
            'MC_001',
            byKey.get(expectedB).Component_Id__c,
            'Component_Id__c for FieldB should match the mock.'
        );
        Assert.areEqual(
            'SomeClass',
            byKey.get(expectedA).Component_Name__c,
            'Component_Name__c for FieldA should match the mock.'
        );
        Assert.areEqual(
            'SomeClass',
            byKey.get(expectedB).Component_Name__c,
            'Component_Name__c for FieldB should match the mock.'
        );
    }
}
