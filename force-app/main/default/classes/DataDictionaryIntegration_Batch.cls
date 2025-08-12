/**
 * DataDictionaryIntegration_Batch
 * System.schedule(
    'DataDictionaryIntegration_Batch',
    '0 0 0/2 * * ?',
    new DataDictionaryIntegration_Batch(2) // or omit arg for default/custom setting
  );
 */
public with sharing class DataDictionaryIntegration_Batch implements Database.Batchable<SObject>, Database.Stateful, Schedulable {
    // ======= CONFIG =======
    private String originalTransactionId;
    private Integer daysThreshold;
    private String integrationUserRole = 'Integration User';
    private static final String STATUS_ACTIVE = 'Active'; // filter value
    private static final String STATUS_ERROR = 'Error'; // target value when failing

    // ----- Constructors -----
    public DataDictionaryIntegration_Batch() {
        this.daysThreshold = resolveThreshold(2);
    }

    public DataDictionaryIntegration_Batch(Integer customDays) {
        this.daysThreshold = resolveThreshold(
            (customDays != null && customDays > 0) ? customDays : 2
        );
    }

    // Read from Hierarchy CS if present; otherwise use fallback/default.
    private Integer resolveThreshold(Integer fallback) {
        try {
            // Optional Hierarchy Custom Setting: Data_Dictionary_Settings__c.Integration_User_Days_Check__c
            // Delete this block if you don't use the setting.
            Data_Dictionary_Settings__c cs = Data_Dictionary_Settings__c.getInstance();
            if (
                cs != null &&
                cs.Integration_User_Days_Check__c != null &&
                cs.Integration_User_Days_Check__c > 0
            ) {
                return Integer.valueOf(cs.Integration_User_Days_Check__c);
            }
        } catch (Exception e) {
            // ignore; use fallback
        }
        return fallback;
    }

    // ======= Batchable =======
    public Database.QueryLocator start(Database.BatchableContext bc) {
        this.originalTransactionId = Logger.getTransactionId();

        // Filter by Status__c = 'Active' (no checkbox)
        String soql =
            'SELECT Id, Name, Status__c, Error_Message__c, ' +
            '       (SELECT Id, Role__c, User__c, ' +
            '               User__r.Id, User__r.Name, User__r.IsActive, User__r.LastLoginDate ' +
            '          FROM Main_Stakeholders__r) ' +
            '  FROM Integration_Service__c ' +
            ' WHERE Status__c = :STATUS_ACTIVE OR Status__c = :STATUS_ERROR';

        Logger.info('Starting DataDictionaryIntegration_Batch');
        Logger.saveLog();

        return Database.getQueryLocator(soql);
    }

    public void execute(
        Database.BatchableContext bc,
        List<Integration_Service__c> scope
    ) {
        DateTime cutoff = System.now().addDays(-daysThreshold);
        List<Integration_Service__c> toUpdate = new List<Integration_Service__c>();

        for (Integration_Service__c svc : scope) {
            // Find the "Integration User" stakeholder
            User integrationUser = null;
            if (svc.Main_Stakeholders__r != null) {
                for (Main_Stakeholder__c ms : svc.Main_Stakeholders__r) {
                    if (
                        ms.Role__c == integrationUserRole &&
                        ms.User__r != null
                    ) {
                        integrationUser = ms.User__r;
                        break;
                    }
                }
            }

            // Build error message based on conditions
            String err = null;
            if (integrationUser == null) {
                err =
                    'No Main Stakeholder with role "' +
                    integrationUserRole +
                    '" is linked to a User.';
            } else if (integrationUser.IsActive == false) {
                err =
                    'Integration User "' +
                    integrationUser.Name +
                    '" is inactive.';
            } else if (integrationUser.LastLoginDate == null) {
                err =
                    'Integration User "' +
                    integrationUser.Name +
                    '" has never logged in.';
            } else if (integrationUser.LastLoginDate < cutoff) {
                err =
                    'Integration User "' +
                    integrationUser.Name +
                    '" last login ' +
                    String.valueOf(integrationUser.LastLoginDate) +
                    ' is older than ' +
                    String.valueOf(daysThreshold) +
                    ' day(s).';
            }

            // If an error condition exists, mark service as Error and set message
            if (err != null) {
                toUpdate.add(
                    new Integration_Service__c(
                        Id = svc.Id,
                        Status__c = STATUS_ERROR,
                        Error_Message__c = err
                    )
                );
            } else if (svc.Status__c == STATUS_ERROR) {
                toUpdate.add(
                    new Integration_Service__c(
                        Id = svc.Id,
                        Status__c = STATUS_ACTIVE,
                        Error_Message__c = null
                    )
                );
            }
        }

        if (!toUpdate.isEmpty()) {
            Database.SaveResult[] results = Database.update(toUpdate, false);
            Logger.info('Updating Integration Services', results);
        }
    }

    public void finish(Database.BatchableContext bc) {
        Logger.setParentLogTransactionId(this.originalTransactionId);

        Logger.info('Finishing running DataDictionaryIntegration_Batch');
        Logger.saveLog();
    }

    // ======= Schedulable =======
    // Allows direct scheduling of the batch via CRON.
    public void execute(SchedulableContext sc) {
        Database.executeBatch(
            new DataDictionaryIntegration_Batch(this.daysThreshold),
            200
        );
    }
}
