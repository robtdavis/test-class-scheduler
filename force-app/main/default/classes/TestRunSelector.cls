/**
 * Read/query access to Test_Schedule__c, Test_Schedule_Class__c, and Test_Run__c, plus the
 * platform's own ApexTestRunResult/ApexTestResult objects (queryable via plain Apex SOQL - see
 * RealPlatformTestRunGateway for why those two are wrapped behind a gateway instead of being
 * called directly by services: their data can't be fabricated in a test, so a service calling
 * this selector's platform-object methods directly would be untestable).
 * Selectors must not call services or controllers.
 */
public inherited sharing class TestRunSelector {
  private static final String SCHEDULE_FIELDS =
    'Id, Name, Active__c, Run_Time__c, Time_Zone__c, Run_All_Tests__c, ' +
    'Sunday__c, Monday__c, Tuesday__c, Wednesday__c, Thursday__c, Friday__c, Saturday__c, ' +
    'Notification_Recipients__c, Cron_Job_Id__c, Cron_Expression__c';

  private static final String RUN_FIELDS =
    'Id, Test_Schedule__c, Async_Apex_Job_Id__c, Status__c, Is_All_Tests__c, Started_Date__c, ' +
    'Completed_Date__c, Total_Tests__c, Passed_Tests__c, Failed_Tests__c, Summary__c, ' +
    'Failure_Details__c, Coverage_Percent__c, Notification_Sent__c, Notification_Recipients__c';

  public List<Test_Schedule__c> getAllSchedules() {
    return Database.query(
      'SELECT ' +
        SCHEDULE_FIELDS +
        ' FROM Test_Schedule__c ORDER BY CreatedDate ASC',
      AccessLevel.USER_MODE
    );
  }

  public List<Test_Schedule_Class__c> getClassesForSchedules(
    Set<Id> scheduleIds
  ) {
    return [
      SELECT Test_Schedule__c, Apex_Class_Id__c
      FROM Test_Schedule_Class__c
      WHERE Test_Schedule__c IN :scheduleIds
      WITH USER_MODE
    ];
  }

  public Map<Id, CronTrigger> getScheduleTriggers(Set<Id> triggerIds) {
    // IDs originate only from schedule records the caller can read.
    return new Map<Id, CronTrigger>(
      [
        SELECT Id, State, NextFireTime, PreviousFireTime, TimeZoneSidKey
        FROM CronTrigger
        WHERE Id IN :triggerIds
      ]
    );
  }

  public Test_Schedule__c getScheduleById(Id scheduleId) {
    List<Test_Schedule__c> results = Database.query(
      'SELECT ' +
        SCHEDULE_FIELDS +
        ' FROM Test_Schedule__c WHERE Id = :scheduleId LIMIT 1',
      AccessLevel.USER_MODE
    );
    return results.isEmpty() ? null : results[0];
  }

  /**
   * Locks the schedule row for the remainder of the current transaction (FOR UPDATE), so two
   * concurrent Run Now/scheduled-fire attempts for the same schedule serialize instead of both
   * passing the "no active run" check. Not USER_MODE: callers reach this only after already
   * authorizing the schedule read via getScheduleById, so this internal lock read doesn't need to
   * re-enforce FLS/CRUD.
   */
  public Test_Schedule__c lockSchedule(Id scheduleId) {
    List<Test_Schedule__c> results = [
      SELECT Id, Run_All_Tests__c, Notification_Recipients__c
      FROM Test_Schedule__c
      WHERE Id = :scheduleId
      LIMIT 1
      FOR UPDATE
    ];
    return results.isEmpty() ? null : results[0];
  }

  public List<Test_Schedule_Class__c> getSelectedClasses(Id scheduleId) {
    return [
      SELECT Id, Apex_Class_Id__c, Apex_Class_Name__c
      FROM Test_Schedule_Class__c
      WHERE Test_Schedule__c = :scheduleId
      WITH USER_MODE
      ORDER BY Apex_Class_Name__c ASC
    ];
  }

  public Test_Run__c getLatestRun(Id scheduleId) {
    List<Test_Run__c> runs = getRecentRuns(scheduleId, 1);
    return runs.isEmpty() ? null : runs[0];
  }

  public Test_Run__c getRunById(Id runId) {
    List<Test_Run__c> runs = Database.query(
      'SELECT ' + RUN_FIELDS + ' FROM Test_Run__c WHERE Id = :runId LIMIT 1',
      AccessLevel.USER_MODE
    );
    return runs.isEmpty() ? null : runs[0];
  }

  public List<Test_Run__c> getRecentRuns(Id scheduleId, Integer maxResults) {
    return Database.query(
      'SELECT ' +
        RUN_FIELDS +
        ' FROM Test_Run__c WHERE Test_Schedule__c = :scheduleId ' +
        'ORDER BY CreatedDate DESC, Id DESC LIMIT :maxResults',
      AccessLevel.USER_MODE
    );
  }

  /**
   * Runs for a schedule that are still in flight, used to prevent starting a duplicate run while
   * one is already active.
   */
  public List<Test_Run__c> getActiveRuns(Id scheduleId) {
    return [
      SELECT Id, Status__c
      FROM Test_Run__c
      WHERE
        Test_Schedule__c = :scheduleId
        AND Status__c IN ('Queued', 'Preparing', 'Processing')
      WITH USER_MODE
    ];
  }

  /**
   * All in-flight runs (any schedule) started before the given cutoff, used by
   * TestMonitoringService.recoverStaleRuns() to sweep and finalize runs whose monitor job never
   * completed them (e.g. because the org paused/removed the scheduled job).
   */
  public List<Test_Run__c> getStaleActiveRuns(Datetime startedBefore) {
    return Database.query(
      'SELECT ' +
        RUN_FIELDS +
        ' FROM Test_Run__c WHERE Status__c IN (\'Queued\', \'Preparing\', \'Processing\') ' +
        'AND Started_Date__c < :startedBefore',
      AccessLevel.USER_MODE
    );
  }

  /**
   * Current status/counters for an in-progress or completed test run. Available in plain Apex
   * SOQL (unlike ApexCodeCoverageAggregate/ApexOrgWideCoverage, which are Tooling-API-only).
   */
  public ApexTestRunResult getApexTestRunResult(String asyncApexJobId) {
    if (String.isBlank(asyncApexJobId)) {
      return null;
    }
    List<ApexTestRunResult> results = [
      SELECT
        Status,
        ClassesCompleted,
        ClassesEnqueued,
        MethodsCompleted,
        MethodsEnqueued,
        MethodsFailed
      FROM ApexTestRunResult
      WHERE AsyncApexJobId = :asyncApexJobId
      LIMIT 1
    ];
    return results.isEmpty() ? null : results[0];
  }

  /** Only failed method results are retrieved - passing methods aren't persisted per MVP scope. */
  public List<ApexTestResult> getFailedApexTestResults(String asyncApexJobId) {
    if (String.isBlank(asyncApexJobId)) {
      return new List<ApexTestResult>();
    }
    return [
      SELECT ApexClassId, MethodName, Message, StackTrace
      FROM ApexTestResult
      WHERE AsyncApexJobId = :asyncApexJobId AND Outcome = 'Fail'
    ];
  }
}
