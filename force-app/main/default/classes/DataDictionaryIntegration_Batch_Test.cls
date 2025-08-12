@IsTest
private class DataDictionaryIntegration_Batch_Test {
    // -------------------------
    // SETUP: runs in its own transaction
    // -------------------------
    @testSetup
    static void setupUsers() {
        // Minimal standard profile
        Profile p = [
            SELECT Id
            FROM Profile
            WHERE UserType = 'Standard'
            LIMIT 1
        ];

        // Helper for unique usernames
        String ts = String.valueOf(System.now().getTime());

        // Active user (never logged in)
        User uActive = new User(
            ProfileId = p.Id,
            Username = 'active_' + ts + '@example.com',
            Email = 'active_' + ts + '@example.com',
            LastName = 'ActiveUser_' + ts,
            Alias = 'actv' + ts.substring(ts.length() - 4),
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            IsActive = true
        );
        insert uActive;

        // Inactive user
        User uInactive = new User(
            ProfileId = p.Id,
            Username = 'inactive_' + ts + '@example.com',
            Email = 'inactive_' + ts + '@example.com',
            LastName = 'InactiveUser_' + ts,
            Alias = 'inac' + ts.substring(ts.length() - 4),
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            IsActive = true
        );
        insert uInactive;
        update new User(Id = uInactive.Id, IsActive = false);
    }

    private static User getActiveUser() {
        return [
            SELECT Id, Name
            FROM User
            WHERE IsActive = TRUE AND Username LIKE 'active_%@example.com'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
    }
    private static User getInactiveUser() {
        return [
            SELECT Id, Name
            FROM User
            WHERE IsActive = FALSE AND Username LIKE 'inactive_%@example.com'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
    }

    // -------------------------
    // TEST 1: Batch behavior (NON-setup DML only)
    // -------------------------
    @IsTest
    static void testBatch_ErrorsAndFilters_noMixedDml() {
        User activeUser = getActiveUser();
        User inactiveUser = getInactiveUser();

        // 1) Active service with NO stakeholder -> should Error ("No Main Stakeholder...")
        Integration_Service__c svcNoStake = new Integration_Service__c(
            Name = 'SVC - No Stakeholder',
            Status__c = 'Active',
            Direction__c = 'Bi-directional'
        );
        // 2) Active service with INACTIVE integration user -> should Error ("is inactive")
        Integration_Service__c svcInactive = new Integration_Service__c(
            Name = 'SVC - Inactive User',
            Status__c = 'Active',
            Direction__c = 'Bi-directional'
        );
        // 3) Active service with ACTIVE user who never logged in -> should Error ("never logged in")
        Integration_Service__c svcNeverLogged = new Integration_Service__c(
            Name = 'SVC - Never Logged In',
            Status__c = 'Active',
            Direction__c = 'Bi-directional'
        );
        // 4) Non-active service -> should be skipped
        Integration_Service__c svcSkipped = new Integration_Service__c(
            Name = 'SVC - Skipped',
            Status__c = 'Disabled',
            Direction__c = 'Bi-directional'
        );
        insert new List<Integration_Service__c>{
            svcNoStake,
            svcInactive,
            svcNeverLogged,
            svcSkipped
        };

        // Attach stakeholders for #2 and #3 (NON-setup object)
        Main_Stakeholder__c msInactive = new Main_Stakeholder__c(
            Role__c = 'Integration User',
            User__c = inactiveUser.Id,
            Integration_Service__c = svcInactive.Id // update API name if needed
        );
        Main_Stakeholder__c msActiveNever = new Main_Stakeholder__c(
            Role__c = 'Integration User',
            User__c = activeUser.Id,
            Integration_Service__c = svcNeverLogged.Id // update API name if needed
        );
        insert new List<Main_Stakeholder__c>{ msInactive, msActiveNever };

        Test.startTest();
        // Small batch size to exercise execute() multiple times
        Database.executeBatch(new DataDictionaryIntegration_Batch(), 100);
        Test.stopTest();

        // Assert results
        Map<Id, Integration_Service__c> byId = new Map<Id, Integration_Service__c>(
            [
                SELECT Id, Status__c, Error_Message__c
                FROM Integration_Service__c
                WHERE
                    Id IN :new List<Id>{
                        svcNoStake.Id,
                        svcInactive.Id,
                        svcNeverLogged.Id,
                        svcSkipped.Id
                    }
            ]
        );

        Assert.areEqual(
            'Error',
            byId.get(svcNoStake.Id).Status__c,
            'No-stakeholder should be Error'
        );
        Assert.isTrue(
            byId.get(svcNoStake.Id)
                .Error_Message__c.contains('No Main Stakeholder'),
            'Expected missing stakeholder message'
        );

        Assert.areEqual(
            'Error',
            byId.get(svcInactive.Id).Status__c,
            'Inactive user case should be Error'
        );
        Assert.isTrue(
            byId.get(svcInactive.Id).Error_Message__c.contains('is inactive'),
            'Expected "is inactive" message'
        );

        Assert.areEqual(
            'Error',
            byId.get(svcNeverLogged.Id).Status__c,
            'Never-logged-in case should be Error'
        );
        Assert.isTrue(
            byId.get(svcNeverLogged.Id)
                .Error_Message__c.contains('never logged in'),
            'Expected "never logged in" message'
        );

        Assert.areEqual(
            'Disabled',
            byId.get(svcSkipped.Id).Status__c,
            'Non-active service must remain unchanged'
        );
        Assert.areEqual(
            null,
            byId.get(svcSkipped.Id).Error_Message__c,
            'Skipped service should not have error message'
        );
    }

    @IsTest
    static void testScheduler_Enqueues() {
        // No non-setup DML in this method.
        Test.startTest();
        String cron = '0 0 0/2 * * ?'; // every 2 hours
        System.schedule(
            'DataDictionaryIntegration_Batch (Test)',
            cron,
            new DataDictionaryIntegration_Batch(2)
        );
        Test.stopTest();

        // Optional: verify CronTrigger exists (read-only)
        CronTrigger ct = [
            SELECT Id, CronExpression, TimesTriggered
            FROM CronTrigger
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        Assert.areEqual(
            cron,
            ct.CronExpression,
            'Cron expression should match'
        );
    }
}
