global class DataDictionaryFields_Batch implements Database.Batchable<SObjectType> {
    
    global Iterable<SObjectType> start(Database.BatchableContext bc){

        // In a test context, only run for the Account object to avoid limit issues
        if (Test.isRunningTest()) {
            return new List<SObjectType>{ Account.sObjectType };
        }

        List<SObjectType> scopeList = new List<SObjectType>();
        //loop through list of all objects in Salesforce org aside from the ignore type objects
        for(SObjectType scopeObject :Schema.getGlobalDescribe().values()){
            string scopeText = string.valueOf(scopeObject);
            boolean ignore = scopeText.endsWith('History') || scopeText.endsWith('ChangeEvent') || scopeText.endsWith('Share');//the ChangeEvents are mirrors to the object and share/history have a common schema
            if(!ignore){
                scopeList.add(scopeObject);
            }
        }
        return scopeList;
    }
    
    global void execute(Database.BatchableContext bc, List<SObjectType> scope){
        
        //create list and loop through to get the list of objects in scope
        List<String> scopeObjectsList = new List<String>();
        for(Schema.SObjectType objType : scope){
            scopeObjectsList.add(String.ValueOf(objType));
        }
        
        //get current list of Data Fields
		List<Data_Field__c> dataFieldList = [Select Data_Object__r.Name, Data_Object__r.Id,Name,Durable_Id__c,Name__c,Entity_Definition_Id__c,Namespace_Prefix__c,Local_Name__c,
                                                   Length__c,Data_Type__c,Extra_Type_Info__c,Calculated__c,Is_High_Scale_Number__c,HTML_Formatted__c,Is_Name_Field__c,Nillable__c,
                                                   Is_Workflow_Filterable__c,Is_Compact_Layoutable__c,Precision__c,Scale__c,Is_Field_History_Tracked__c,Is_Indexed__c,Filterable__c,
                                                   Is_Api_Sortable__c,Is_List_Filterable__c,Is_List_Sortable__c,Groupable__c,Is_List_Visible__c,Controlling_Field_Definition_Id__c,
                                                   Last_Modified_Date__c,Last_Modified_By_Id__c,Relationship_Name__c,Is_Compound__c,Search_Prefilterable__c,Is_Polymorphic_Foreign_Key__c,
                                                   Business_Owner_Id__c,Business_Status__c,Security_Classification__c,Description__c,AI_Prediction_Field__c,
                                                   Calculated_Formula__c,Default_Value__c,Deprecated_and_Hidden__c,Formula_Treat_Null_Number_As_Zero__c,Inline_Help_Text__c,Permissionable__c,
                                                   Reference_To__c,Restricted_Picklist__c,SObject_Field__c,Auto_Number__c,Cascade_Delete__c,Default_Value_Formula__c,Digits__c,Label__c,
                                                   Name_Field__c,Picklist_Values__c,Type__c,Byte_Length__c,Controller__c,Defaulted_On_Create__c,External_Id__c,Name_Pointing__c,Unique__c,
                                                   Relationship_Order__c,Reference_Target_Field__c,Restricted_Delete__c,Soap_Type__c,Write_Requires_Master_Read__c,Id_Lookup__c,Custom__c,
                                                   Dependent_Picklist__c, Deleted__c 
                                                   from Data_Field__c where Data_Object__r.Name IN :scopeObjectsList and Deleted__c = false];
       //create DataField Map
       Map<String, Data_Field__c> dataFieldsMap = new Map<String, Data_Field__c>();
        //loop through and create a key for the current object fields also add to map for deleting
        for(Data_Field__c dataField : dataFieldList){
            String dataFieldKey = dataField.Name + '|' + dataField.Data_Object__r.Name;//Field names are not org unique, this will make them unique
            dataFieldsMap.put(dataFieldKey, dataField);
        }
        
        //get field definitions
        List<FieldDefinition> fieldDefinitionList = [Select Id,EntityDefinition.QualifiedApiName, DurableId, QualifiedApiName, EntityDefinitionId, 
                                                                NamespacePrefix, Label, Length, DataType, 
                                                                ExtraTypeInfo, IsCalculated, IsHighScaleNumber, IsHtmlFormatted, IsNameField, IsNillable, IsWorkflowFilterable, 
                                                                IsCompactLayoutable, Precision, Scale, IsFieldHistoryTracked, IsIndexed, IsApiFilterable, IsApiSortable, 
                                                                IsListFilterable, IsListSortable, IsApiGroupable, IsListVisible, ControllingFieldDefinitionId, LastModifiedDate, 
                                                                LastModifiedById, RelationshipName, IsCompound, IsSearchPrefilterable, IsPolymorphicForeignKey, BusinessOwnerId, 
                                                                BusinessStatus, SecurityClassification, Description 
                                                                FROM FieldDefinition where EntityDefinition.QualifiedApiName IN :scopeObjectsList];
         
        Map<String, FieldDefinition> fieldDefinitionMap = new Map<String, FieldDefinition>();
        //loop through and create a key for the fieldDefinitions
        for(FieldDefinition fieldDef : fieldDefinitionList){
            String fieldDefinitionKey = fieldDef.QualifiedApiName + '|' + fieldDef.EntityDefinition.QualifiedApiName;//create the same key as above this will be to see if any fields change
            fieldDefinitionMap.put(fieldDefinitionKey,fieldDef);
        }
        
        Map<String, Id> grabObjectMap = new Map<String, Id>();
        List<Data_Object__c> grabObjectIdList = [Select Id, Name from Data_Object__c where Name IN :scopeObjectsList];
        //Loop through Object records to get a map for the field record to lookup to the Object record
        for(Data_Object__c objectId : grabObjectIdList){
            grabObjectMap.put(objectId.Name, objectId.Id);
        }
        
        //setup for matching fields - get list of tracked fields based on the metadata
        List<Data_Dictionary_Tracked_Field__mdt> trackedFieldsList = [Select Label from Data_Dictionary_Tracked_Field__mdt];
        List<String> trackedFieldsStringList = new List<String>();
        for(Data_Dictionary_Tracked_Field__mdt trackedField :trackedFieldsList){
            trackedFieldsStringList.add(trackedField.Label);
        }
        
        List<Data_Field__c> addFieldList = new List<Data_Field__c>();
        List<Data_Field__c> updateFieldList = new List<Data_Field__c>();
        
        //loop through all of the objects in the scope
        for ( Schema.SObjectType typ : scope ) {
            String sobjName = String.valueOf(typ);
            Map <String, Schema.SObjectField> fieldMap = typ.getDescribe().fields.getMap();
            
            for(Schema.SObjectField field : fieldMap.Values()) {
                schema.describefieldresult describefield = field.getDescribe();
                String fieldName = describefield.getName();
                String createKey = fieldName + '|' + sobjName;
                Data_Field__c currentFieldValues = dataFieldsMap.get(createKey);
                
                If(currentFieldValues != null){
                    Data_Field__c potentialNewDataField = DataDictionaryUtility.createNewDataField(fieldDefinitionMap.get(createKey), describefield, currentFieldValues.Id, currentFieldValues.Data_Object__r.Id);
                    boolean matching = DataDictionaryUtility.dataDictionaryFieldsMatching(dataFieldsMap.get(createKey), potentialNewDataField, trackedFieldsStringList);
                    if(!matching){
                        updateFieldList.add(potentialNewDataField);
                    }
                } else {
                    Data_Field__c newDataField = DataDictionaryUtility.createNewDataField(fieldDefinitionMap.get(createKey), describefield);
                    newDataField.Data_Object__c = grabObjectMap.get(sobjName);
                    addFieldList.add(newDataField);
                }
                dataFieldsMap.remove(createKey);
            }
        }

       if (!addFieldList.isEmpty()) insert addFieldList;
       if (!updateFieldList.isEmpty()) update updateFieldList;
       
       // Any remaining records in the map are obsolete and should be soft-deleted
       for(Data_Field__c df :dataFieldsMap.values()){
           df.Deleted__c = true;
       }
       if (!dataFieldsMap.isEmpty()) update dataFieldsMap.values();
    }
    
    global void finish(Database.BatchableContext bc){
        // **Modification for Testability**
        // By wrapping the chained job in this condition, we prevent it from running
        // during a test. This allows us to test this batch class in isolation
        // without causing governor limit exceptions. This has no effect on production runs.
        if (!Test.isRunningTest()) {
            System.enqueueJob(new DataDictionaryRecordType_Queueable());
        }
    }
}