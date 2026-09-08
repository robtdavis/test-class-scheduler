/**
 * Initiates Apex test runs by inserting ApexTestQueueItem records (the Salesforce-supported,
 * callout-free mechanism for enqueuing asynchronous test execution - see ApexTestQueueItem object
 * reference). Bulk-inserting the queue items for all target classes in one DML statement gives them
 * a shared ParentJobId, which is the AsyncApexJobId used to track the run via ApexTestRunResult.
 * Monitoring that run to completion and sending the notification email are handled by
 * TestRunMonitor/TestNotificationService in a later increment; this service only starts the run and
 * records a Test_Run__c row in "Queued" status.
 */
public with sharing class TestExecutionService {
  private final TestRunSelector runSelector = new TestRunSelector();
  private final TestClassSelector classSelector = new TestClassSelector();
  private final ITestRunGateway gateway;

  public TestExecutionService() {
    this(new ApexTestQueueGateway());
  }

  @TestVisible
  private TestExecutionService(ITestRunGateway gateway) {
    this.gateway = gateway;
  }

  /** Invoked by TestScheduleJob when a scheduled CRON fires. */
  public Id startScheduledRun(Id scheduleId) {
    return enqueueRun(scheduleId);
  }

  /** Invoked by the "Run Now" action in the LWC. */
  public Id runNow(Id scheduleId) {
    return enqueueRun(scheduleId);
  }

  private Id enqueueRun(Id scheduleId) {
    Test_Schedule__c schedule = runSelector.getScheduleById(scheduleId);
    if (schedule == null) {
      throw new TestExecutionException('Schedule not found.');
    }
    if (!runSelector.getActiveRuns(scheduleId).isEmpty()) {
      throw new TestExecutionException(
        'A test run is already in progress for this schedule.'
      );
    }

    Set<Id> classIds = new Set<Id>();
    if (schedule.Run_All_Tests__c) {
      for (ApexClass cls : classSelector.getAllTestClasses()) {
        classIds.add(cls.Id);
      }
    } else {
      for (
        Test_Schedule_Class__c junction : runSelector.getSelectedClasses(
          scheduleId
        )
      ) {
        classIds.add((Id) junction.Apex_Class_Id__c);
      }
    }
    if (classIds.isEmpty()) {
      throw new TestExecutionException(
        'No Apex test classes are configured for this schedule.'
      );
    }

    String parentJobId = gateway.enqueueClasses(classIds);

    Test_Run__c run = new Test_Run__c(
      Test_Schedule__c = scheduleId,
      Async_Apex_Job_Id__c = parentJobId,
      Status__c = 'Queued',
      Is_All_Tests__c = schedule.Run_All_Tests__c,
      Started_Date__c = Datetime.now(),
      Notification_Recipients__c = schedule.Notification_Recipients__c
    );
    Database.insert(new List<Test_Run__c>{ run }, AccessLevel.USER_MODE);

    return run.Id;
  }

  public class TestExecutionException extends Exception {
  }
}
