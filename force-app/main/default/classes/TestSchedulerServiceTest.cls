@isTest
private class TestSchedulerServiceTest {
  @testSetup
  static void setup() {
    TestSchedulerTestUtils.assignAdminPermissionSet();
  }

  @isTest
  static void buildCronExpression_singleDay_producesExpectedCron() {
    TestSchedulerService service = new TestSchedulerService();
    String cron = service.buildCronExpression(
      8,
      30,
      false,
      true,
      false,
      false,
      false,
      false,
      false
    );
    System.assertEquals(
      '0 30 8 ? * MON',
      cron,
      'Single weekday should produce a single-day cron list'
    );
  }

  @isTest
  static void buildCronExpression_multipleDays_producesOrderedCommaList() {
    TestSchedulerService service = new TestSchedulerService();
    String cron = service.buildCronExpression(
      9,
      0,
      true,
      false,
      false,
      true,
      false,
      true,
      false
    );
    System.assertEquals(
      '0 0 9 ? * SUN,WED,FRI',
      cron,
      'Days should appear in Sun-Sat order regardless of input order of booleans'
    );
  }

  @isTest
  static void buildCronExpression_noDaysSelected_throws() {
    TestSchedulerService service = new TestSchedulerService();
    try {
      service.buildCronExpression(
        9,
        0,
        false,
        false,
        false,
        false,
        false,
        false,
        false
      );
      System.assert(false, 'Expected an exception when no weekday is selected');
    } catch (TestSchedulerService.TestSchedulerException ex) {
      System.assert(ex.getMessage().contains('at least one day'));
    }
  }

  @isTest
  static void buildCronExpression_invalidHour_throws() {
    TestSchedulerService service = new TestSchedulerService();
    try {
      service.buildCronExpression(
        24,
        0,
        true,
        false,
        false,
        false,
        false,
        false,
        false
      );
      System.assert(false, 'Expected an exception for an out-of-range hour');
    } catch (TestSchedulerService.TestSchedulerException ex) {
      System.assert(ex.getMessage().contains('hour'));
    }
  }

  @isTest
  static void saveSchedule_selectedClasses_createsScheduleAndActivatesJob() {
    Id classId = [
      SELECT Id
      FROM ApexClass
      WHERE Name = 'SchedulerFixtureTestOne'
      LIMIT 1
    ]
    .Id;
    TestScheduleDTO input = buildInput(true, false, new List<Id>{ classId });

    Test.startTest();
    TestScheduleDTO saved = new TestSchedulerService().saveSchedule(input);
    Test.stopTest();

    System.assertNotEquals(
      null,
      saved.scheduleId,
      'Schedule should be persisted'
    );
    System.assertEquals('0 0 8 ? * MON', saved.cronExpression);
    System.assertNotEquals(
      null,
      saved.cronJobId,
      'Active schedule should have a live CronTrigger'
    );
    System.assertEquals(UserInfo.getTimeZone().getID(), saved.timeZone);
    System.assertEquals(1, saved.selectedClassIds.size());

    CronTrigger ct = [
      SELECT CronExpression
      FROM CronTrigger
      WHERE Id = :saved.cronJobId
    ];
    System.assertEquals('0 0 8 ? * MON', ct.CronExpression);
  }

  @isTest
  static void saveSchedule_runAllTests_doesNotRequireSelectedClasses() {
    TestScheduleDTO input = buildInput(true, true, new List<Id>());

    Test.startTest();
    TestScheduleDTO saved = new TestSchedulerService().saveSchedule(input);
    Test.stopTest();

    System.assertEquals(true, saved.runAllTests);
    System.assertEquals(0, saved.selectedClassIds.size());
  }

  @isTest
  static void saveSchedule_withoutSelectionOrRunAll_throws() {
    TestScheduleDTO input = buildInput(true, false, new List<Id>());
    try {
      new TestSchedulerService().saveSchedule(input);
      System.assert(
        false,
        'Expected an exception when no classes are selected and Run All Tests is off'
      );
    } catch (TestSchedulerService.TestSchedulerException ex) {
      System.assert(ex.getMessage().contains('Select at least one'));
    }
  }

  @isTest
  static void saveSchedule_missingRecipients_throws() {
    TestScheduleDTO input = buildInput(true, true, new List<Id>());
    input.notificationRecipients = '';
    try {
      new TestSchedulerService().saveSchedule(input);
      System.assert(false, 'Expected an exception for missing recipients');
    } catch (TestSchedulerService.TestSchedulerException ex) {
      System.assert(ex.getMessage().contains('recipient'));
    }
  }

  @isTest
  static void saveSchedule_invalidRecipientEmail_throws() {
    TestScheduleDTO input = buildInput(true, true, new List<Id>());
    input.notificationRecipients = 'not-an-email';
    try {
      new TestSchedulerService().saveSchedule(input);
      System.assert(
        false,
        'Expected an exception for an invalid recipient email'
      );
    } catch (TestSchedulerService.TestSchedulerException ex) {
      System.assert(ex.getMessage().contains('Invalid notification recipient'));
    }
  }

  @isTest
  static void saveSchedule_reschedule_abortsPreviousJobAndAvoidsDuplicates() {
    TestScheduleDTO input = buildInput(true, true, new List<Id>());
    Test.startTest();
    TestScheduleDTO first = new TestSchedulerService().saveSchedule(input);

    TestScheduleDTO revised = buildInput(true, true, new List<Id>());
    revised.scheduleId = first.scheduleId;
    revised.monday = false;
    revised.tuesday = true;
    TestScheduleDTO second = new TestSchedulerService().saveSchedule(revised);
    Test.stopTest();

    System.assertNotEquals(
      first.cronJobId,
      second.cronJobId,
      'Rescheduling should replace the CronTrigger'
    );
    System.assertEquals('0 0 8 ? * TUE', second.cronExpression);

    // The job name is deterministic per schedule Id, so the old job must have been aborted
    // before the new one was created (System.schedule throws if a job with the same name is
    // already active) - exactly one job should exist for this schedule, never more.
    Integer jobsForSchedule = [
      SELECT COUNT()
      FROM CronTrigger
      WHERE CronJobDetail.Name = :('TestSchedule_' + first.scheduleId)
    ];
    System.assertEquals(
      1,
      jobsForSchedule,
      'Exactly one (non-duplicated) job should be scheduled after reschedule'
    );
  }

  @isTest
  static void deactivateSchedule_clearsJobAndFlag() {
    TestScheduleDTO input = buildInput(true, true, new List<Id>());
    Test.startTest();
    TestScheduleDTO saved = new TestSchedulerService().saveSchedule(input);
    new TestSchedulerService().deactivateSchedule(saved.scheduleId);
    Test.stopTest();

    Test_Schedule__c record = [
      SELECT Active__c, Cron_Job_Id__c
      FROM Test_Schedule__c
      WHERE Id = :saved.scheduleId
    ];
    System.assertEquals(false, record.Active__c);
    System.assertEquals(null, record.Cron_Job_Id__c);
  }

  @isTest
  static void deleteSchedule_removesRecordAndChildren() {
    Id classId = [
      SELECT Id
      FROM ApexClass
      WHERE Name = 'SchedulerFixtureTestOne'
      LIMIT 1
    ]
    .Id;
    TestScheduleDTO input = buildInput(true, false, new List<Id>{ classId });
    Test.startTest();
    TestScheduleDTO saved = new TestSchedulerService().saveSchedule(input);
    new TestSchedulerService().deleteSchedule(saved.scheduleId);
    Test.stopTest();

    System.assertEquals(
      0,
      [SELECT COUNT() FROM Test_Schedule__c WHERE Id = :saved.scheduleId]
    );
    System.assertEquals(
      0,
      [
        SELECT COUNT()
        FROM Test_Schedule_Class__c
        WHERE Test_Schedule__c = :saved.scheduleId
      ]
    );
  }

  private static TestScheduleDTO buildInput(
    Boolean active,
    Boolean runAllTests,
    List<Id> selectedClassIds
  ) {
    TestScheduleDTO dto = new TestScheduleDTO();
    dto.active = active;
    dto.runAllTests = runAllTests;
    dto.runTimeHour = 8;
    dto.runTimeMinute = 0;
    dto.monday = true;
    dto.notificationRecipients = 'admin@example.com';
    dto.selectedClassIds = selectedClassIds;
    return dto;
  }
}
