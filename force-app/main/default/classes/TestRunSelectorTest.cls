@isTest
private class TestRunSelectorTest {
  @testSetup
  static void setup() {
    TestSchedulerTestUtils.assignAdminPermissionSet();
  }

  @isTest
  static void getAllSchedules_and_getScheduleById_returnPersistedRecord() {
    Test_Schedule__c schedule = insertSchedule();

    TestRunSelector selector = new TestRunSelector();
    System.assertEquals(1, selector.getAllSchedules().size());
    System.assertEquals(schedule.Id, selector.getScheduleById(schedule.Id).Id);
    System.assertEquals(null, selector.getScheduleById(null));
  }

  @isTest
  static void getSelectedClasses_returnsJunctionsForSchedule() {
    Test_Schedule__c schedule = insertSchedule();
    insert new Test_Schedule_Class__c(
      Test_Schedule__c = schedule.Id,
      Apex_Class_Id__c = UserInfo.getUserId(),
      Apex_Class_Name__c = 'SomeFixtureClass'
    );

    List<Test_Schedule_Class__c> classes = new TestRunSelector()
      .getSelectedClasses(schedule.Id);
    System.assertEquals(1, classes.size());
  }

  @isTest
  static void getRecentRuns_and_getLatestRun_orderByMostRecentFirst() {
    Test_Schedule__c schedule = insertSchedule();
    Test_Run__c older = new Test_Run__c(
      Test_Schedule__c = schedule.Id,
      Status__c = 'Completed'
    );
    insert older;
    Test_Run__c newer = new Test_Run__c(
      Test_Schedule__c = schedule.Id,
      Status__c = 'Queued'
    );
    insert newer;

    TestRunSelector selector = new TestRunSelector();
    System.assertEquals(newer.Id, selector.getLatestRun(schedule.Id).Id);
    System.assertEquals(2, selector.getRecentRuns(schedule.Id, 5).size());
    System.assertEquals(newer.Id, selector.getRunById(newer.Id).Id);
  }

  @isTest
  static void getActiveRuns_onlyReturnsInFlightStatuses() {
    Test_Schedule__c schedule = insertSchedule();
    insert new Test_Run__c(
      Test_Schedule__c = schedule.Id,
      Status__c = 'Completed'
    );
    Test_Run__c active = new Test_Run__c(
      Test_Schedule__c = schedule.Id,
      Status__c = 'Processing'
    );
    insert active;

    List<Test_Run__c> activeRuns = new TestRunSelector()
      .getActiveRuns(schedule.Id);
    System.assertEquals(1, activeRuns.size());
    System.assertEquals(active.Id, activeRuns[0].Id);
  }

  private static Test_Schedule__c insertSchedule() {
    Test_Schedule__c schedule = new Test_Schedule__c(
      Active__c = false,
      Run_Time__c = Time.newInstance(8, 0, 0, 0),
      Run_All_Tests__c = true,
      Monday__c = true,
      Notification_Recipients__c = 'admin@example.com'
    );
    insert schedule;
    return schedule;
  }
}
