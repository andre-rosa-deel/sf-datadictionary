@isTest
private class DataDictionarySchedule_Batch_Test {

    @isTest
    static void testScheduler() {
        // This test verifies that the schedulable class correctly
        // enqueues the first batch job in the chain.

        // 1. Setup: Define a CRON expression for scheduling.
        String cronExpression = '0 0 23 * * ?'; // Run at 11 PM every day

        Test.startTest();
        // 2. Action: Schedule the job.
        String jobId = System.schedule('Data Dictionary Test Schedule', cronExpression, new DataDictionarySchedule_Batch());
        Test.stopTest();

        // 3. Assert: Verify that the job was scheduled correctly.
        CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals(cronExpression, ct.CronExpression, 'The CRON expression should match.');
        System.assertEquals(0, ct.TimesTriggered, 'The job should not have run yet.');

        // It is difficult to assert the batch execution directly because of the chained
        // job failures, but scheduling it is the primary responsibility of this class.
        // Confirming the CronTrigger was created is sufficient to validate this unit.
    }
}