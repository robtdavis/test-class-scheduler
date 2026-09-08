/**
 * Asynchronous monitoring of in-flight Apex test runs: polls ApexTestRunResult without busy-waiting
 * (each check reschedules a single one-time job for itself a few minutes later rather than looping
 * or polling continuously), collects failure details and best-effort coverage on completion, and
 * recovers runs that never reach a terminal status within a bounded window (e.g. because their
 * monitor job was paused/removed by the org). Scheduling mechanics for the recurring poll live here
 * (mirrors TestSchedulerService owning System.schedule for the main job) - TestRunMonitor itself
 * stays a thin Schedulable that only delegates here.
 */
public with sharing class TestMonitoringService {
  @TestVisible
  private static final Integer POLL_INTERVAL_MINUTES = 2;
  @TestVisible
  private static final Integer STALE_THRESHOLD_MINUTES = 180;
  private static final String MONITOR_JOB_PREFIX = 'TestRunMonitor_';
  /** Test-only counter of scheduleNextCheck() calls, since real scheduling is skipped in tests. */
  @TestVisible
  private static Integer scheduleAttemptCount = 0;

  private final TestRunSelector runSelector = new TestRunSelector();
  private final IPlatformTestRunGateway platformGateway;
  private final IToolingCoverageGateway coverageGateway;
  private final TestResultService resultService = new TestResultService();
  private final TestNotificationService notificationService;

  public TestMonitoringService() {
    this(
      new RealPlatformTestRunGateway(),
      new ToolingApiCoverageGateway(),
      new TestNotificationService()
    );
  }

  @TestVisible
  private TestMonitoringService(
    IPlatformTestRunGateway platformGateway,
    IToolingCoverageGateway coverageGateway,
    TestNotificationService notificationService
  ) {
    this.platformGateway = platformGateway;
    this.coverageGateway = coverageGateway;
    this.notificationService = notificationService;
  }

  /** Kicks off the first poll for a newly-enqueued run. */
  public void startMonitoring(Id testRunId) {
    scheduleNextCheck(testRunId);
  }

  /** Invoked by TestRunMonitor when a scheduled poll fires. Idempotent on an already-final run. */
  public void checkStatus(Id testRunId) {
    Test_Run__c run = runSelector.getRunById(testRunId);
    if (run == null || isTerminal(run.Status__c)) {
      return;
    }

    PlatformRunStatus snapshot = platformGateway.getRunStatus(
      run.Async_Apex_Job_Id__c
    );
    if (snapshot.found && snapshot.isTerminal()) {
      List<FailedTestInfo> failures = snapshot.methodsFailed > 0
        ? platformGateway.getFailedResults(run.Async_Apex_Job_Id__c)
        : new List<FailedTestInfo>();
      applyCompletion(run, snapshot);
      finalizeAndNotify(run, failures, null);
      return;
    }
    if (isStale(run.Started_Date__c)) {
      finalizeAndNotify(run, new List<FailedTestInfo>(), staleNote());
      return;
    }
    if (snapshot.found) {
      applyInFlightCounts(run, snapshot);
      Database.update(new List<Test_Run__c>{ run }, AccessLevel.USER_MODE);
    }
    scheduleNextCheck(testRunId);
  }

  /**
   * Bulk-safe sweep for runs whose monitor job never finalized them (e.g. the CronTrigger was
   * removed by the org). Finalizes every stale run and sends all notifications in a single
   * Messaging.sendEmail invocation, regardless of how many runs are recovered in one call.
   */
  public void recoverStaleRuns() {
    Datetime cutoff = Datetime.now().addMinutes(-STALE_THRESHOLD_MINUTES);
    List<Test_Run__c> staleRuns = runSelector.getStaleActiveRuns(cutoff);
    if (staleRuns.isEmpty()) {
      return;
    }
    List<Test_Run__c> toUpdate = new List<Test_Run__c>();
    List<EmailRequest> emails = new List<EmailRequest>();
    for (Test_Run__c run : staleRuns) {
      String summaryText = applyTerminalFields(
        run,
        new List<FailedTestInfo>(),
        staleNote()
      );
      toUpdate.add(run);
      try {
        emails.add(
          notificationService.buildRequest(
            run,
            summaryText,
            run.Failure_Details__c
          )
        );
        run.Notification_Sent__c = true;
      } catch (TestNotificationService.TestNotificationException ex) {
        run.Summary__c += '\n(Notification not sent: ' + ex.getMessage() + ')';
      }
    }
    Database.update(toUpdate, AccessLevel.USER_MODE);
    notificationService.sendBatch(emails);
  }

  private void applyCompletion(Test_Run__c run, PlatformRunStatus snapshot) {
    run.Status__c = snapshot.status;
    run.Total_Tests__c = snapshot.methodsEnqueued;
    run.Passed_Tests__c = Math.max(
      0,
      snapshot.methodsCompleted - snapshot.methodsFailed
    );
    run.Failed_Tests__c = snapshot.methodsFailed;
    run.Completed_Date__c = Datetime.now();
  }

  private void applyInFlightCounts(
    Test_Run__c run,
    PlatformRunStatus snapshot
  ) {
    run.Status__c = String.isNotBlank(snapshot.status)
      ? snapshot.status
      : run.Status__c;
    run.Total_Tests__c = snapshot.methodsEnqueued;
    run.Passed_Tests__c = Math.max(
      0,
      snapshot.methodsCompleted - snapshot.methodsFailed
    );
    run.Failed_Tests__c = snapshot.methodsFailed;
  }

  /** Sets Status/Completed_Date/Coverage/Summary/Failure_Details on a run being finalized. */
  private String applyTerminalFields(
    Test_Run__c run,
    List<FailedTestInfo> failures,
    String extraNote
  ) {
    if (extraNote != null) {
      run.Status__c = 'Failed';
      run.Completed_Date__c = Datetime.now();
    }
    Decimal coverage = coverageGateway.getOrgWideCoveragePercent();
    run.Coverage_Percent__c = coverage;
    String summaryText = resultService.buildSummaryText(run, coverage);
    if (extraNote != null) {
      summaryText = extraNote + '\n\n' + summaryText;
    }
    run.Summary__c = summaryText;
    run.Failure_Details__c = resultService.buildFailureDetailsText(failures);
    return summaryText;
  }

  private void finalizeAndNotify(
    Test_Run__c run,
    List<FailedTestInfo> failures,
    String extraNote
  ) {
    String summaryText = applyTerminalFields(run, failures, extraNote);
    try {
      notificationService.sendRunCompletionEmail(
        run,
        summaryText,
        run.Failure_Details__c
      );
      run.Notification_Sent__c = true;
    } catch (TestNotificationService.TestNotificationException ex) {
      run.Summary__c += '\n(Notification not sent: ' + ex.getMessage() + ')';
    }
    Database.update(new List<Test_Run__c>{ run }, AccessLevel.USER_MODE);
  }

  private String staleNote() {
    return 'Monitoring timed out after ' +
      STALE_THRESHOLD_MINUTES +
      ' minutes without a terminal ApexTestRunResult status; marked Failed for recovery.';
  }

  private Boolean isStale(Datetime startedDate) {
    return startedDate != null &&
      startedDate < Datetime.now().addMinutes(-STALE_THRESHOLD_MINUTES);
  }

  private Boolean isTerminal(String status) {
    return status == 'Completed' || status == 'Failed' || status == 'Aborted';
  }

  private void scheduleNextCheck(Id testRunId) {
    scheduleAttemptCount++;
    if (Test.isRunningTest()) {
      // Test.stopTest() executes scheduled jobs immediately regardless of their configured
      // fire time, so actually calling System.schedule here during a test would recursively
      // re-fire this same check (and its own reschedule) until some other limit is hit. This
      // mirrors ApexTestQueueGateway's Test.isRunningTest() guard for the same underlying
      // reason. Tests assert on scheduleAttemptCount instead of a real CronTrigger row.
      return;
    }
    Datetime fireTime = Datetime.now().addMinutes(POLL_INTERVAL_MINUTES);
    String cron = buildOneTimeCron(fireTime);
    String jobName = MONITOR_JOB_PREFIX + testRunId + '_' + fireTime.getTime();
    try {
      System.schedule(jobName, cron, new TestRunMonitor(testRunId));
    } catch (Exception ex) {
      // If scheduling the next check fails (e.g. the org-wide scheduled-job limit is
      // reached), the run is left as-is; recoverStaleRuns() is the safety net that will
      // eventually finalize it once the stale threshold passes.
    }
  }

  private String buildOneTimeCron(Datetime fireTime) {
    return fireTime.second() +
      ' ' +
      fireTime.minute() +
      ' ' +
      fireTime.hour() +
      ' ' +
      fireTime.day() +
      ' ' +
      fireTime.month() +
      ' ? ' +
      fireTime.year();
  }
}
