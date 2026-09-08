/**
 * Read/query access to Test_Schedule__c, Test_Schedule_Class__c, and Test_Run__c.
 * Selectors must not call services or controllers.
 */
public inherited sharing class TestRunSelector {
  private static final String SCHEDULE_FIELDS =
    'Id, Name, Active__c, Run_Time__c, Time_Zone__c, Run_All_Tests__c, ' +
    'Sunday__c, Monday__c, Tuesday__c, Wednesday__c, Thursday__c, Friday__c, Saturday__c, ' +
    'Notification_Recipients__c, Cron_Job_Id__c, Cron_Expression__c';

  public List<Test_Schedule__c> getAllSchedules() {
    return Database.query(
      'SELECT ' +
        SCHEDULE_FIELDS +
        ' FROM Test_Schedule__c ORDER BY CreatedDate ASC',
      AccessLevel.USER_MODE
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
    List<Test_Run__c> runs = [
      SELECT
        Id,
        Status__c,
        Is_All_Tests__c,
        Started_Date__c,
        Completed_Date__c,
        Total_Tests__c,
        Passed_Tests__c,
        Failed_Tests__c,
        Summary__c,
        Failure_Details__c
      FROM Test_Run__c
      WHERE Id = :runId
      WITH USER_MODE
      LIMIT 1
    ];
    return runs.isEmpty() ? null : runs[0];
  }

  public List<Test_Run__c> getRecentRuns(Id scheduleId, Integer maxResults) {
    return [
      SELECT
        Id,
        Status__c,
        Is_All_Tests__c,
        Started_Date__c,
        Completed_Date__c,
        Total_Tests__c,
        Passed_Tests__c,
        Failed_Tests__c,
        Summary__c,
        Failure_Details__c
      FROM Test_Run__c
      WHERE Test_Schedule__c = :scheduleId
      WITH USER_MODE
      ORDER BY CreatedDate DESC, Id DESC
      LIMIT :maxResults
    ];
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
}
