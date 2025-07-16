public class DataDictionaryObjects_Batch implements Database.Batchable<SObjectType>, Database.Stateful {

    // Stateful variables to track objects across transactions
    private List<Data_Object__c> currentDataObjectList = new List<Data_Object__c>();
    private List<String> currentObjectNamesList = new List<String>();
    private Map<String, Data_Object__c> currentObjMap = new Map<String, Data_Object__c>();
    
    public Iterable<SObjectType> start(Database.BatchableContext bc){
        // This logic MUST run in both test and production contexts to correctly 
        // populate the stateful map before the execute method runs.
        this.currentDataObjectList = [Select Name, Label__c, Custom__c, Custom_Setting__c, 
                                             Feed_Enabled__c, Has_Subtypes__c, Label_Plural__c, 
                                             Mergeable__c, Record_Type_Dev_Names__c, Record_Type_Names__c 
                                      from Data_Object__c];

        for(Data_Object__c objects : currentDataObjectList){
            currentObjectNamesList.add(objects.Name);
            currentObjMap.put(objects.Name, objects);
        }
        
        // In a test context, return a small, controlled scope for the execute() method.
        if (Test.isRunningTest()) {
            return new List<SObjectType>{ Account.sObjectType, Contact.sObjectType };
        }

        // In a production context, return all objects.
        return Schema.getGlobalDescribe().values();
    }
    
    public void execute(Database.BatchableContext bc, List<SObjectType> scope){
        
        List<Data_Object__c> newDataObjectList = new List<Data_Object__c>();
	    List<Data_Object__c> updatedDataObjectList = new List<Data_Object__c>();
        
        for ( Schema.SObjectType typ : scope ) {
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
            for(Schema.RecordTypeInfo objectRecordTypeInfo : objectResult.getRecordTypeInfos()){
                recordTypeNameList.add(objectRecordTypeInfo.getName());
                recordTypeDevNameList.add(objectRecordTypeInfo.getDeveloperName());
            }
            String recordtypename = String.join(recordTypeNameList, ', ');
            String recordtypedevname = String.join(recordTypeDevNameList, ', ');
            
            if(currentObjectNamesList.contains(sobjName)){
                Data_Object__c checkObjectUpdate = currentObjMap.get(sobjName);
                currentObjMap.remove(sobjName); 
                
                if(checkObjectUpdate.Custom__c != custom
                   || checkObjectUpdate.Custom_Setting__c != customSetting
                   || checkObjectUpdate.Feed_Enabled__c != feedEnabled
                   || checkObjectUpdate.Has_Subtypes__c != hasSubTypes
                   || checkObjectUpdate.Label_Plural__c != labelPlural
                   || checkObjectUpdate.Mergeable__c != mergeable
                   || checkObjectUpdate.Record_Type_Dev_Names__c != recordtypedevname 
                   || checkObjectUpdate.Record_Type_Names__c != recordtypename){
                       
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
            insert newDataObjectList;
        }
        if (!updatedDataObjectList.isEmpty()) {
            update updatedDataObjectList;
        }
    }
    
    public void finish(Database.BatchableContext bc){
        if (!currentObjMap.isEmpty()) {
            delete currentObjMap.values();
        }
        
        // Only chain the next job if not in a test context.
        if (!Test.isRunningTest()) {
            DataDictionaryFields_Batch ddfb = new DataDictionaryFields_Batch();
            Database.executeBatch(ddfb);
        }
    }
}