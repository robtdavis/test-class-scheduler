@isTest
private class TestExecutionServiceTest {
  @testSetup
  static void setup() {
    TestSchedulerTestUtils.assignAdminPermissionSet();
  }

  @isTest
  static void runNow_selectedClasses_enqueuesConfiguredClassAndCreatesRunRecord() {
    Id classId = [
      SELECT Id
      FROM ApexClass
      WHERE Name = 'SchedulerFixtureTestOne'
      LIMIT 1
    ]
    .Id;
    Test_Schedule__c schedule = new Test_Schedule__c(
      Active__c = true,
      Run_Time__c = Time.newInstance(8, 0, 0, 0),
      Run_All_Tests__c = false,
      Monday__c = true,
      Notification_Recipients__c = 'admin@example.com'
    );
    insert schedule;
    insert new Test_Schedule_Class__c(
      Test_Schedule__c = schedule.Id,
      Apex_Class_Id__c = classId,
      Apex_Class_Name__c = 'SchedulerFixtureTestOne'
    );

    FakeTestRunGateway gateway = new FakeTestRunGateway();
    gateway.jobIdToReturn = '707FAKE00000000BBB';

    Test.startTest();
    Id runId = new TestExecutionService(gateway).runNow(schedule.Id);
    Test.stopTest();

    System.assertEquals(1, gateway.invocationCount);
    System.assertEquals(1, gateway.lastEnqueuedClassIds.size());
    System.assert(gateway.lastEnqueuedClassIds.contains(classId));

    Test_Run__c run = [
      SELECT
        Status__c,
        Is_All_Tests__c,
        Async_Apex_Job_Id__c,
        Notification_Recipients__c
      FROM Test_Run__c
      WHERE Id = :runId
    ];
    System.assertEquals('Queued', run.Status__c);
    System.assertEquals(false, run.Is_All_Tests__c);
    System.assertEquals('707FAKE00000000BBB', run.Async_Apex_Job_Id__c);
    System.assertEquals('admin@example.com', run.Notification_Recipients__c);
  }

  @isTest
  static void runNow_runAllTests_resolvesEveryTestClass() {
    Test_Schedule__c schedule = new Test_Schedule__c(
      Active__c = true,
      Run_Time__c = Time.newInstance(8, 0, 0, 0),
      Run_All_Tests__c = true,
      Monday__c = true,
      Notification_Recipients__c = 'admin@example.com'
    );
    insert schedule;

    Integer testClassCount = new TestClassSelector().getAllTestClasses().size();
    FakeTestRunGateway gateway = new FakeTestRunGateway();

    Test.startTest();
    Id runId = new TestExecutionService(gateway).runNow(schedule.Id);
    Test.stopTest();

    Test_Run__c run = [
      SELECT Is_All_Tests__c
      FROM Test_Run__c
      WHERE Id = :runId
    ];
    System.assertEquals(true, run.Is_All_Tests__c);
    System.assertEquals(testClassCount, gateway.lastEnqueuedClassIds.size());
  }

  @isTest
  static void runNow_defaultGateway_stillCreatesRunRecordInTestContext() {
    // ApexTestQueueGateway (the real, production gateway) must not perform the disallowed
    // ApexTestQueueItem insert while a test is running; it should return a synthetic job id so
    // the rest of the flow (including a CRON job firing during Test.stopTest) works safely.
    Test_Schedule__c schedule = new Test_Schedule__c(
      Active__c = true,
      Run_Time__c = Time.newInstance(8, 0, 0, 0),
      Run_All_Tests__c = true,
      Monday__c = true,
      Notification_Recipients__c = 'admin@example.com'
    );
    insert schedule;

    Test.startTest();
    Id runId = new TestExecutionService().runNow(schedule.Id);
    Test.stopTest();

    Test_Run__c run = [
      SELECT Status__c, Async_Apex_Job_Id__c
      FROM Test_Run__c
      WHERE Id = :runId
    ];
    System.assertEquals('Queued', run.Status__c);
    System.assertNotEquals(null, run.Async_Apex_Job_Id__c);
  }

  @isTest
  static void runNow_whenActiveRunExists_throws() {
    Test_Schedule__c schedule = new Test_Schedule__c(
      Active__c = true,
      Run_Time__c = Time.newInstance(8, 0, 0, 0),
      Run_All_Tests__c = true,
      Monday__c = true,
      Notification_Recipients__c = 'admin@example.com'
    );
    insert schedule;
    insert new Test_Run__c(
      Test_Schedule__c = schedule.Id,
      Status__c = 'Processing'
    );

    try {
      new TestExecutionService(new FakeTestRunGateway()).runNow(schedule.Id);
      System.assert(
        false,
        'Expected an exception when a run is already active'
      );
    } catch (TestExecutionService.TestExecutionException ex) {
      System.assert(ex.getMessage().contains('already in progress'));
    }
  }

  @isTest
  static void runNow_noClassesConfigured_throws() {
    Test_Schedule__c schedule = new Test_Schedule__c(
      Active__c = true,
      Run_Time__c = Time.newInstance(8, 0, 0, 0),
      Run_All_Tests__c = false,
      Monday__c = true,
      Notification_Recipients__c = 'admin@example.com'
    );
    insert schedule;

    try {
      new TestExecutionService(new FakeTestRunGateway()).runNow(schedule.Id);
      System.assert(
        false,
        'Expected an exception when no classes are configured'
      );
    } catch (TestExecutionService.TestExecutionException ex) {
      System.assert(ex.getMessage().contains('No Apex test classes'));
    }
  }

  @isTest
  static void runNow_scheduleNotFound_throws() {
    try {
      new TestExecutionService(new FakeTestRunGateway()).runNow(null);
      System.assert(false, 'Expected an exception for a missing schedule');
    } catch (TestExecutionService.TestExecutionException ex) {
      System.assert(ex.getMessage().contains('not found'));
    }
  }
}
