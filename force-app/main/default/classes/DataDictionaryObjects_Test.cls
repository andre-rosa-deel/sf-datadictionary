@IsTest
private class DataDictionaryObjects_Test {
    @IsTest
    static void testValuesClass() {
        DataDictionaryObjects.ValuesClass value = new DataDictionaryObjects.ValuesClass(
            new DataDictionaryObjects.Attributes(),
            'Test Label',
            new List<String>{ 'val1', 'val2' },
            'Test Value'
        );

        Assert.areEqual('Test Label', value.label);
        Assert.areEqual(2, value.validFor.size());
        Assert.areEqual('Test Value', value.value);
    }

    @IsTest
    static void testDataFieldScopeWrapper() {
        DataDictionaryObjects.DataFieldScopeWrapper wrapper = new DataDictionaryObjects.DataFieldScopeWrapper();
        wrapper.dataFieldsIdMap = new Map<String, Id>{
            'TestKey' => UserInfo.getUserId()
        };
        wrapper.ScopeRecordTypeIdSet = new Set<Id>{ UserInfo.getUserId() };

        Assert.areEqual(1, wrapper.dataFieldsIdMap.size());
        Assert.areEqual(1, wrapper.ScopeRecordTypeIdSet.size());
    }

    @IsTest
    static void testHeaderObject() {
        DataDictionaryObjects.HeaderObject header = new DataDictionaryObjects.HeaderObject();
        header.key = 'TestKey';
        header.value = 'TestValue';

        Assert.areEqual('TestKey', header.key);
        Assert.areEqual('TestValue', header.value);
    }
}
