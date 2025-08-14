global class DataDictionaryPicklist_Batch implements Database.Batchable<sObject>, Database.RaisesPlatformEvents, Database.AllowsCallouts, Database.Stateful {
    private String originalTransactionId;

    global Iterable<sObject> start(Database.BatchableContext bc) {
        this.originalTransactionId = Logger.getTransactionId();
        List<RecordType> RTList = [
            SELECT
                Id,
                Name,
                DeveloperName,
                NamespacePrefix,
                Description,
                BusinessProcessId,
                SobjectType,
                IsActive,
                CreatedById,
                CreatedDate,
                LastModifiedById,
                LastModifiedDate,
                SystemModstamp
            FROM RecordType
        ];

        Logger.info('Starting DataDictionaryPicklist_Batch');
        Logger.saveLog();

        return RTList;
    }

    global void execute(Database.BatchableContext bc, List<RecordType> scope) {
        Logger.setParentLogTransactionId(this.originalTransactionId);

        //map for Getting DataObjectRecordType Id
        Map<Id, Id> dataObjRTMap = new Map<Id, Id>();
        for (Data_Object_Record_Type__c dataObjRT : [
            SELECT Id, Record_Type_Id__c
            FROM Data_Object_Record_Type__c
        ]) {
            dataObjRTMap.put(dataObjRT.Record_Type_Id__c, dataObjRT.Id);
        }

        //get map of all data fields in scope used to get the DataField Id for creating a picklist value and associate to the
        DataDictionaryObjects.DataFieldScopeWrapper scopeWrapper = DataDictionaryUtility.dataFieldsInScope(
            scope
        );
        Map<String, Id> dataFieldsIdMap = scopeWrapper.dataFieldsIdMap;
        //Ids used for DataFieldDelete SOQL
        Set<Id> scopeRecordTypeIdSet = scopeWrapper.ScopeRecordTypeIdSet;
        //current Picklist Fields
        List<Data_Field_Record_Type_Picklist__c> currentRTPList = new List<Data_Field_Record_Type_Picklist__c>(
            [
                SELECT
                    Id,
                    Name,
                    Picklist_API_Name__c,
                    Data_Field__r.Name,
                    Data_Field__r.Data_Object__r.Name,
                    Data_Object_Record_Type__c
                FROM Data_Field_Record_Type_Picklist__c
                WHERE
                    Data_Field__c IN :dataFieldsIdMap.values()
                    AND Data_Object_Record_Type__r.Record_Type_Id__c IN :scopeRecordTypeIdSet
            ]
        );
        //map with the current Picklist values based on a key with the CurrentRTPList - when checked for a current VCItem will be removed and used as a delete list
        Map<String, Data_Field_Record_Type_Picklist__c> currentDFRTPMap = new Map<String, Data_Field_Record_Type_Picklist__c>();
        //If not in the currentDFRTPMap will be added to the insert List
        List<Data_Field_Record_Type_Picklist__c> insertDFRTP = new List<Data_Field_Record_Type_Picklist__c>();
        for (Data_Field_Record_Type_Picklist__c currentDFRTP : currentRTPList) {
            //used to Identify if the value is a current value
            String currentKey =
                currentDFRTP.Data_Field__r.Id +
                '|' +
                currentDFRTP.Data_Object_Record_Type__c +
                '|' +
                currentDFRTP.Name +
                '|' +
                currentDFRTP.Picklist_API_Name__c;
            currentDFRTPMap.put(currentKey, currentDFRTP);
        }

        for (RecordType RT : scope) {
            Map<String, Object> untype = DataDictionaryHttpClass.getPicklists(
                RT.SobjectType,
                RT.Id,
                UserInfo.getSessionId()
            );
            //Used for gettting the datafield Id in a map
            String dataObjectName = RT.SobjectType;

            //get the picklist values
            try {
                Map<String, Object> pickFieldUntype = (Map<String, Object>) untype.get(
                    'picklistFieldValues'
                );
                //need to loop through the keyset to be able to get the keyset and the values of the map
                for (String loopValueKeySet : pickFieldUntype.keySet()) {
                    Object loopValue = pickFieldUntype.get(loopValueKeySet);
                    //used for a key with DataObject name to get the field Id
                    String dataFieldName = loopValueKeySet;
                    String dataFieldKey =
                        dataObjectName +
                        '|' +
                        loopValueKeySet;
                    Map<String, Object> loopValMap = (Map<String, Object>) loopValue;
                    String serial = JSON.serialize(loopValMap.get('values'));
                    List<DataDictionaryObjects.ValuesClass> vclist = (List<DataDictionaryObjects.ValuesClass>) JSON.deserialize(
                        serial,
                        List<DataDictionaryObjects.ValuesClass>.class
                    );
                    system.debug(vclist);
                    for (DataDictionaryObjects.ValuesClass vcItem : vcList) {
                        Data_Field_Record_Type_Picklist__c vcDFRTP = DataDictionaryUtility.createDFRTP(
                            vcItem,
                            dataFieldsIdMap.get(dataFieldKey),
                            dataObjRTMap.get(RT.Id)
                        );
                        String key =
                            vcDFRTP.Data_Field__c +
                            '|' +
                            vcDFRTP.Data_Object_Record_Type__c +
                            '|' +
                            vcDFRTP.Name +
                            '|' +
                            vcDFRTP.Picklist_API_Name__c;
                        if (currentDFRTPMap.get(key) == null) {
                            insertDFRTP.add(vcDFRTP);
                        } else {
                            currentDFRTPMap.remove(key);
                        }
                    }
                }
            } catch (Exception e) {
                Logger.error('Exception Error Message.', e);
                system.debug('Exception Error Message: ' + e.getMessage());
                continue;
            }
        }

        if (!insertDFRTP.isEmpty()) {
            List<Database.SaveResult> result = Database.insert(
                insertDFRTP,
                false
            );
            Logger.info('Inserting Data Field Picklists', result);
        }
        if (!currentDFRTPMap.values().isEmpty()) {
            List<Database.DeleteResult> result = Database.delete(
                currentDFRTPMap.values(),
                false
            );
            Logger.info('Deleting Data Field Picklists', result);
        }

        Logger.saveLog();
    }
    global void finish(Database.BatchableContext bc) {
        Logger.setParentLogTransactionId(this.originalTransactionId);

        Logger.info('Finishing running DataDictionaryPicklist_Batch');
        Logger.saveLog();

        if (!Test.isRunningTest()) {
            DataDictionaryUtility.submitMetadataReferencesBatch();
        }
    }
}
