global class DataDictionaryReference_Batch implements Database.Batchable<sObject>, Database.RaisesPlatformEvents, Database.AllowsCallouts, Database.Stateful {
    public static final String QUERY_TEMPLATE =
        'SELECT MetadataComponentType, MetadataComponentName, RefMetadataComponentName, RefMetadataComponentId, RefMetadataComponentType, MetadataComponentId, MetadataComponentNamespace ' +
        'FROM MetadataComponentDependency ' +
        'WHERE RefMetadataComponentType = \'CustomField\' and RefMetadataComponentId = {0} ' +
        'ORDER By RefMetadataComponentName';
    private String originalTransactionId;

    global Iterable<sObject> start(Database.BatchableContext bc) {
        this.originalTransactionId = Logger.getTransactionId();

        List<Data_Field__c> dataFields = [
            SELECT Id, Name, Field_Id__c
            FROM Data_Field__c
            WHERE Field_Id__c != NULL
        ];

        Logger.info('Starting DataDictionaryReference_Batch');
        Logger.saveLog();

        return dataFields;
    }

    global void execute(
        Database.BatchableContext bc,
        List<Data_Field__c> scope
    ) {
        Logger.setParentLogTransactionId(this.originalTransactionId);

        List<Metadata_Component_Reference__c> existingReferences = [
            SELECT
                Id,
                Name,
                Component_Id__c,
                Component_Type__c,
                Component_Namespace__c,
                Component_Name__c,
                External_Id__c,
                Data_Field__c,
                Data_Field__r.Field_Id__c
            FROM Metadata_Component_Reference__c
        ];
        Map<String, Metadata_Component_Reference__c> existingReferencesMap = new Map<String, Metadata_Component_Reference__c>();
        for (Metadata_Component_Reference__c mc : existingReferences) {
            existingReferencesMap.put(mc.External_Id__c, mc);
        }

        Map<String, Metadata_Component_Reference__c> referencesToUpsert = new Map<String, Metadata_Component_Reference__c>();
        Map<String, Metadata_Component_Reference__c> referencesToDelete = new Map<String, Metadata_Component_Reference__c>();

        for (Data_Field__c dataField : scope) {
            Map<String, Object> untype = DataDictionaryHttpClass.getMetadataReferences(
                String.format(
                    QUERY_TEMPLATE,
                    new List<String>{ '\'' + dataField.Field_Id__c + '\'' }
                ),
                UserInfo.getSessionId()
            );

            try {
                List<Object> references = (List<Object>) untype.get('records');

                for (Object ref : references) {
                    Map<String, Object> reference = (Map<String, Object>) ref;
                    String key =
                        dataField.Field_Id__c +
                        '|' +
                        (String) reference.get('MetadataComponentId');
                    Metadata_Component_Reference__c newReference = new Metadata_Component_Reference__c(
                        Data_Field__c = dataField.Id,
                        Component_Id__c = (String) reference.get(
                            'MetadataComponentId'
                        ),
                        Component_Type__c = (String) reference.get(
                            'MetadataComponentType'
                        ),
                        Component_Namespace__c = (String) reference.get(
                            'MetadataComponentNamespace'
                        ),
                        Component_Name__c = (String) reference.get(
                            'MetadataComponentName'
                        ),
                        External_Id__c = key
                    );

                    referencesToUpsert.put(key, newReference);
                }
            } catch (Exception e) {
                Logger.error('Exception Error Message.', e);
                system.debug('Exception Error Message: ' + e.getMessage());
                continue;
            }
        }

        if (!referencesToUpsert.isEmpty()) {
            List<Database.UpsertResult> result = Database.upsert(
                referencesToUpsert.values(),
                Metadata_Component_Reference__c.Fields.External_Id__c,
                false
            );
            Logger.info('Upserting Metadata Component References', result);
        }

        for (Metadata_Component_Reference__c reference : existingReferences) {
            if (!referencesToUpsert.containsKey(reference.External_Id__c)) {
                referencesToDelete.put(reference.External_Id__c, reference);
            }
        }

        if (!referencesToDelete.isEmpty()) {
            List<Database.DeleteResult> result = Database.delete(
                referencesToDelete.values(),
                false
            );
            Logger.info('Deleting Metadata Component References', result);
        }

        Logger.saveLog();
    }
    global void finish(Database.BatchableContext bc) {
        Logger.setParentLogTransactionId(this.originalTransactionId);

        Logger.info('Finishing running DataDictionaryReference_Batch');
        Logger.saveLog();
    }
}
