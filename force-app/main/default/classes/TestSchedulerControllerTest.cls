@isTest
private class TestSchedulerControllerTest {
  @testSetup
  static void setup() {
    TestSchedulerTestUtils.assignAdminPermissionSet();
  }

  @isTest
  static void getTestClassOptions_returnsFixtureClasses() {
    List<TestClassOptionDTO> options = TestSchedulerController.getTestClassOptions(
      'SchedulerFixtureTest'
    );
    System.assert(
      options.size() >= 2,
      'Expected at least the two fixture test classes'
    );
  }

  @isTest
  static void getScheduleConfiguration_noSchedule_returnsNull() {
    System.assertEquals(
      null,
      TestSchedulerController.getScheduleConfiguration()
    );
  }

  @isTest
  static void saveSchedule_thenGetScheduleConfiguration_returnsSavedValues() {
    TestScheduleDTO input = new TestScheduleDTO();
    input.active = true;
    input.runAllTests = true;
    input.runTimeHour = 7;
    input.runTimeMinute = 15;
    input.friday = true;
    input.notificationRecipients = 'admin@example.com';
    input.selectedClassIds = new List<Id>();

    Test.startTest();
    TestScheduleDTO saved = TestSchedulerController.saveSchedule(input);
    TestScheduleDTO fetched = TestSchedulerController.getScheduleConfiguration();
    Test.stopTest();

    System.assertEquals(saved.scheduleId, fetched.scheduleId);
    System.assertEquals('0 15 7 ? * FRI', fetched.cronExpression);
  }

  @isTest
  static void saveSchedule_invalidInput_throwsAuraHandledException() {
    TestScheduleDTO input = new TestScheduleDTO();
    input.active = true;
    input.runAllTests = false;
    input.runTimeHour = 7;
    input.runTimeMinute = 15;
    input.friday = true;
    input.notificationRecipients = 'admin@example.com';
    input.selectedClassIds = new List<Id>();

    try {
      TestSchedulerController.saveSchedule(input);
      System.assert(false, 'Expected an AuraHandledException');
    } catch (AuraHandledException ex) {
      System.assert(ex.getMessage().contains('Select at least one'));
    }
  }

  @isTest
  static void deactivateAndDeleteSchedule_delegateToService() {
    TestScheduleDTO input = new TestScheduleDTO();
    input.active = true;
    input.runAllTests = true;
    input.runTimeHour = 6;
    input.runTimeMinute = 0;
    input.saturday = true;
    input.notificationRecipients = 'admin@example.com';
    input.selectedClassIds = new List<Id>();

    Test.startTest();
    TestScheduleDTO saved = TestSchedulerController.saveSchedule(input);
    TestSchedulerController.deactivateSchedule(saved.scheduleId);
    TestSchedulerController.deleteSchedule(saved.scheduleId);
    Test.stopTest();

    System.assertEquals(
      0,
      [SELECT COUNT() FROM Test_Schedule__c WHERE Id = :saved.scheduleId]
    );
  }

  @isTest
  static void runNow_and_getLatestRun_returnQueuedRun() {
    // Active is left false: Run Now works regardless of activation, and this avoids the
    // schedule's own CronTrigger also firing (and competing for the same active-run guard)
    // when Test.stopTest() simulates scheduled execution.
    TestScheduleDTO input = new TestScheduleDTO();
    input.active = false;
    input.runAllTests = true;
    input.runTimeHour = 6;
    input.runTimeMinute = 0;
    input.sunday = true;
    input.notificationRecipients = 'admin@example.com';
    input.selectedClassIds = new List<Id>();

    Test.startTest();
    TestScheduleDTO saved = TestSchedulerController.saveSchedule(input);
    TestRunDTO runResult = TestSchedulerController.runNow(saved.scheduleId);
    TestRunDTO latest = TestSchedulerController.getLatestRun(saved.scheduleId);
    Test.stopTest();

    System.assertEquals('Queued', runResult.status);
    System.assertEquals(runResult.runId, latest.runId);

    List<TestRunDTO> recent = TestSchedulerController.getRecentRuns(
      saved.scheduleId,
      5
    );
    System.assertEquals(1, recent.size());
    System.assertEquals(runResult.runId, recent[0].runId);
  }
}
