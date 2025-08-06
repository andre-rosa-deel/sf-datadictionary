public class DataDictionaryObjects_Batch implements Database.Batchable<SObjectType>, Database.RaisesPlatformEvents, Database.AllowsCallouts, Database.Stateful {
    // Stateful variables to track objects across transactions
    private transient List<Data_Object__c> currentDataObjectList;
    private Map<String, Data_Object__c> currentObjMap = new Map<String, Data_Object__c>();
    private List<String> currentObjectNamesList = new List<String>();
    private String originalTransactionId;

    // This new variable allows tests to specify a controlled scope for isolation.
    @TestVisible
    private List<SObjectType> testScope;

    public DataDictionaryObjects_Batch() {
        this.currentDataObjectList = [
            SELECT
                Name,
                Label__c,
                Custom__c,
                Custom_Setting__c,
                Feed_Enabled__c,
                Has_Subtypes__c,
                Label_Plural__c,
                Mergeable__c,
                Record_Type_Dev_Names__c,
                Record_Type_Names__c
            FROM Data_Object__c
        ];

        for (Data_Object__c obj : currentDataObjectList) {
            currentObjectNamesList.add(obj.Name);
            currentObjMap.put(obj.Name, obj);
        }
    }

    public Iterable<SObjectType> start(Database.BatchableContext bc) {
        this.originalTransactionId = Logger.getTransactionId();

        if (Test.isRunningTest()) {
            // If the test method has defined a specific scope, use it.
            if (testScope != null && !testScope.isEmpty()) {
                return testScope;
            }
            // Otherwise, use a default scope for other test scenarios.
            return new List<SObjectType>{
                Account.sObjectType,
                Contact.sObjectType
            };
        }
        Logger.info('Starting DataDictionaryObjects_Batch');
        Logger.saveLog();

        // In production, return all objects.
        return Schema.getGlobalDescribe().values();
    }

    public void execute(Database.BatchableContext bc, List<SObjectType> scope) {
        Logger.setParentLogTransactionId(this.originalTransactionId);

        List<Data_Object__c> newDataObjectList = new List<Data_Object__c>();
        List<Data_Object__c> updatedDataObjectList = new List<Data_Object__c>();

        for (Schema.SObjectType typ : scope) {
            String sobjName = String.valueOf(typ);
            Schema.DescribeSObjectResult objectResult = typ.getDescribe();

            Boolean custom = objectResult.isCustom();
            Boolean customSetting = objectResult.isCustomSetting();
            Boolean feedEnabled = objectResult.isFeedEnabled();
            Boolean hasSubTypes = objectResult.getHasSubTypes();
            String labelPlural = objectResult.getLabelPlural();
            Boolean mergeable = objectResult.isMergeable();
            String prefix = objectResult.getKeyPrefix();
            String label = objectResult.getLabel();
            String name = objectResult.getName();

            List<String> recordTypeNameList = new List<String>();
            List<String> recordTypeDevNameList = new List<String>();
            for (
                Schema.RecordTypeInfo objectRecordTypeInfo : objectResult.getRecordTypeInfos()
            ) {
                recordTypeNameList.add(objectRecordTypeInfo.getName());
                recordTypeDevNameList.add(
                    objectRecordTypeInfo.getDeveloperName()
                );
            }
            String recordtypename = String.join(recordTypeNameList, ', ');
            String recordtypedevname = String.join(recordTypeDevNameList, ', ');

            if (currentObjectNamesList.contains(sobjName)) {
                Data_Object__c checkObjectUpdate = currentObjMap.get(sobjName);
                if (
                    checkObjectUpdate.Custom__c != custom ||
                    checkObjectUpdate.Custom_Setting__c != customSetting ||
                    checkObjectUpdate.Feed_Enabled__c != feedEnabled ||
                    checkObjectUpdate.Has_Subtypes__c != hasSubTypes ||
                    checkObjectUpdate.Label_Plural__c != labelPlural ||
                    checkObjectUpdate.Mergeable__c != mergeable ||
                    checkObjectUpdate.Record_Type_Dev_Names__c !=
                    recordtypedevname ||
                    checkObjectUpdate.Record_Type_Names__c != recordtypename
                ) {
                    checkObjectUpdate.Custom__c = custom;
                    checkObjectUpdate.Custom_Setting__c = customSetting;
                    checkObjectUpdate.Feed_Enabled__c = feedEnabled;
                    checkObjectUpdate.Has_Subtypes__c = hasSubTypes;
                    checkObjectUpdate.Label_Plural__c = labelPlural;
                    checkObjectUpdate.Mergeable__c = mergeable;
                    checkObjectUpdate.Record_Type_Dev_Names__c = recordtypedevname;
                    checkObjectUpdate.Record_Type_Names__c = recordtypename;
                    updatedDataObjectList.add(checkObjectUpdate);
                }
                currentObjMap.remove(sobjName);
            } else {
                Data_Object__c newObject = new Data_Object__c(
                    Custom__c = custom,
                    Custom_Setting__c = customSetting,
                    Feed_Enabled__c = feedEnabled,
                    Has_Subtypes__c = hasSubTypes,
                    Label_Plural__c = labelPlural,
                    Mergeable__c = mergeable,
                    Name = name,
                    Prefix__c = prefix,
                    Record_Type_Names__c = recordtypename,
                    Record_Type_Dev_Names__c = recordtypedevname,
                    Label__c = label
                );
                newDataObjectList.add(newObject);
            }
        }

        if (!newDataObjectList.isEmpty()) {
            List<Database.SaveResult> result = Database.insert(
                newDataObjectList,
                false
            );
            Logger.info('Inserting Data Objects', result);
        }
        if (!updatedDataObjectList.isEmpty()) {
            List<Database.SaveResult> result = Database.update(
                updatedDataObjectList,
                false
            );
            Logger.info('Updating Data Objects', result);
        }
    }

    public void finish(Database.BatchableContext bc) {
        Logger.setParentLogTransactionId(this.originalTransactionId);

        if (!currentObjMap.isEmpty()) {
            List<Database.DeleteResult> result = Database.delete(
                currentObjMap.values(),
                false
            );
            Logger.info('Deleting Data Objects', result);
        }

        Logger.info('Finishing running DataDictionaryObjects_Batch');
        Logger.saveLog();

        if (!Test.isRunningTest()) {
            Database.executeBatch(new DataDictionaryFields_Batch());
        }
    }
}
