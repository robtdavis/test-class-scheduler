@isTest
private class TestMonitoringServiceTest {
  @testSetup
  static void setup() {
    TestSchedulerTestUtils.assignAdminPermissionSet();
  }

  @isTest
  static void checkStatus_runNotFound_isNoOp() {
    TestMonitoringService service = buildService(
      new FakePlatformTestRunGateway(),
      new FakeCoverageGateway(),
      new FakeEmailGateway()
    );
    service.checkStatus(null);
    // No exception, nothing to assert further - a missing run is simply ignored.
  }

  @isTest
  static void checkStatus_alreadyTerminal_isIdempotentNoOp() {
    Test_Schedule__c schedule = insertSchedule();
    Test_Run__c run = insertRun(schedule.Id, 'Completed', Datetime.now());

    FakeEmailGateway emailGateway = new FakeEmailGateway();
    buildService(
        new FakePlatformTestRunGateway(),
        new FakeCoverageGateway(),
        emailGateway
      )
      .checkStatus(run.Id);

    System.assertEquals(
      0,
      emailGateway.invocationCount,
      'An already-terminal run must not be re-notified'
    );
  }

  @isTest
  static void checkStatus_terminalWithNoFailures_finalizesAndSendsSuccessEmail() {
    Test_Schedule__c schedule = insertSchedule();
    Test_Run__c run = insertRun(schedule.Id, 'Queued', Datetime.now());

    FakePlatformTestRunGateway platformGateway = new FakePlatformTestRunGateway();
    platformGateway.statusToReturn = buildStatus('Completed', 10, 10, 10, 0);
    FakeCoverageGateway coverageGateway = new FakeCoverageGateway();
    coverageGateway.percentToReturn = 92.5;
    FakeEmailGateway emailGateway = new FakeEmailGateway();

    buildService(platformGateway, coverageGateway, emailGateway)
      .checkStatus(run.Id);

    Test_Run__c updated = [
      SELECT
        Status__c,
        Passed_Tests__c,
        Failed_Tests__c,
        Coverage_Percent__c,
        Notification_Sent__c,
        Completed_Date__c
      FROM Test_Run__c
      WHERE Id = :run.Id
    ];
    System.assertEquals('Completed', updated.Status__c);
    System.assertEquals(10, updated.Passed_Tests__c);
    System.assertEquals(0, updated.Failed_Tests__c);
    System.assertEquals(92.5, updated.Coverage_Percent__c);
    System.assertEquals(true, updated.Notification_Sent__c);
    System.assertNotEquals(null, updated.Completed_Date__c);
    System.assertEquals(1, emailGateway.invocationCount);
    System.assert(emailGateway.lastRequests[0].subject.contains('Success'));
  }

  @isTest
  static void checkStatus_terminalWithFailures_capturesFailureDetailsInEmail() {
    Test_Schedule__c schedule = insertSchedule();
    Test_Run__c run = insertRun(schedule.Id, 'Processing', Datetime.now());

    FakePlatformTestRunGateway platformGateway = new FakePlatformTestRunGateway();
    platformGateway.statusToReturn = buildStatus('Completed', 10, 10, 8, 2);
    FailedTestInfo failure = new FailedTestInfo();
    failure.className = 'SomeClass';
    failure.methodName = 'testBoom';
    failure.message = 'Assertion failed: expected true';
    failure.stackTrace = 'Class.SomeClass.testBoom: line 12';
    platformGateway.failuresToReturn = new List<FailedTestInfo>{ failure };
    FakeEmailGateway emailGateway = new FakeEmailGateway();

    buildService(platformGateway, new FakeCoverageGateway(), emailGateway)
      .checkStatus(run.Id);

    Test_Run__c updated = [
      SELECT Failed_Tests__c, Failure_Details__c
      FROM Test_Run__c
      WHERE Id = :run.Id
    ];
    System.assertEquals(2, updated.Failed_Tests__c);
    System.assert(updated.Failure_Details__c.contains('SomeClass.testBoom'));
    System.assert(emailGateway.lastRequests[0].subject.contains('Failure'));
    System.assert(
      emailGateway.lastRequests[0].body.contains('SomeClass.testBoom')
    );
  }

  @isTest
  static void checkStatus_stillRunning_updatesCountsAndReschedules() {
    Test_Schedule__c schedule = insertSchedule();
    Test_Run__c run = insertRun(schedule.Id, 'Queued', Datetime.now());

    FakePlatformTestRunGateway platformGateway = new FakePlatformTestRunGateway();
    platformGateway.statusToReturn = buildStatus('Processing', 10, 4, 4, 0);
    Integer beforeAttempts = getScheduleAttemptCount();

    buildService(
        platformGateway,
        new FakeCoverageGateway(),
        new FakeEmailGateway()
      )
      .checkStatus(run.Id);

    Test_Run__c updated = [
      SELECT Status__c, Passed_Tests__c
      FROM Test_Run__c
      WHERE Id = :run.Id
    ];
    System.assertEquals('Processing', updated.Status__c);
    System.assertEquals(4, updated.Passed_Tests__c);
    System.assertEquals(
      beforeAttempts + 1,
      getScheduleAttemptCount(),
      'A still-running check should attempt to schedule the next poll'
    );
  }

  @isTest
  static void checkStatus_staleRun_finalizesAsFailedAndNotifies() {
    Test_Schedule__c schedule = insertSchedule();
    Test_Run__c run = insertRun(
      schedule.Id,
      'Queued',
      Datetime.now().addMinutes(-300)
    );

    FakePlatformTestRunGateway platformGateway = new FakePlatformTestRunGateway();
    // Not found/still queued according to the platform - the staleness check should win anyway.
    FakeEmailGateway emailGateway = new FakeEmailGateway();

    buildService(platformGateway, new FakeCoverageGateway(), emailGateway)
      .checkStatus(run.Id);

    Test_Run__c updated = [
      SELECT Status__c, Summary__c, Notification_Sent__c
      FROM Test_Run__c
      WHERE Id = :run.Id
    ];
    System.assertEquals('Failed', updated.Status__c);
    System.assert(updated.Summary__c.contains('timed out'));
    System.assertEquals(true, updated.Notification_Sent__c);
    System.assertEquals(1, emailGateway.invocationCount);
  }

  @isTest
  static void recoverStaleRuns_noStaleRuns_isNoOp() {
    FakeEmailGateway emailGateway = new FakeEmailGateway();
    buildService(
        new FakePlatformTestRunGateway(),
        new FakeCoverageGateway(),
        emailGateway
      )
      .recoverStaleRuns();
    System.assertEquals(0, emailGateway.invocationCount);
  }

  @isTest
  static void recoverStaleRuns_manyStaleRuns_finalizesAllInOneBatchedEmail() {
    Test_Schedule__c schedule = insertSchedule();
    List<Test_Run__c> runs = new List<Test_Run__c>();
    for (Integer i = 0; i < 60; i++) {
      runs.add(
        new Test_Run__c(
          Test_Schedule__c = schedule.Id,
          Status__c = 'Processing',
          Started_Date__c = Datetime.now().addMinutes(-300),
          Notification_Recipients__c = 'admin@example.com'
        )
      );
    }
    insert runs;

    FakeEmailGateway emailGateway = new FakeEmailGateway();
    buildService(
        new FakePlatformTestRunGateway(),
        new FakeCoverageGateway(),
        emailGateway
      )
      .recoverStaleRuns();

    System.assertEquals(
      60,
      [
        SELECT COUNT()
        FROM Test_Run__c
        WHERE Status__c = 'Failed' AND Test_Schedule__c = :schedule.Id
      ]
    );
    System.assertEquals(
      1,
      emailGateway.invocationCount,
      'Recovering many stale runs should still send only one batched email invocation'
    );
    System.assertEquals(60, emailGateway.lastRequests.size());
  }

  @isTest
  static void recoverStaleRuns_someRunsMissingRecipients_stillFinalizesAllRuns() {
    Test_Schedule__c schedule = insertSchedule();
    insert new Test_Run__c(
      Test_Schedule__c = schedule.Id,
      Status__c = 'Queued',
      Started_Date__c = Datetime.now().addMinutes(-300),
      Notification_Recipients__c = null
    );

    FakeEmailGateway emailGateway = new FakeEmailGateway();
    buildService(
        new FakePlatformTestRunGateway(),
        new FakeCoverageGateway(),
        emailGateway
      )
      .recoverStaleRuns();

    System.assertEquals(
      1,
      [
        SELECT COUNT()
        FROM Test_Run__c
        WHERE Status__c = 'Failed' AND Test_Schedule__c = :schedule.Id
      ]
    );
    System.assertEquals(
      0,
      emailGateway.invocationCount,
      'No valid recipients means no email is attempted for that run'
    );
  }

  private static TestMonitoringService buildService(
    IPlatformTestRunGateway platformGateway,
    IToolingCoverageGateway coverageGateway,
    IEmailGateway emailGateway
  ) {
    return new TestMonitoringService(
      platformGateway,
      coverageGateway,
      new TestNotificationService(emailGateway)
    );
  }

  private static PlatformRunStatus buildStatus(
    String status,
    Integer enqueued,
    Integer completed,
    Integer passed,
    Integer failed
  ) {
    PlatformRunStatus snapshot = new PlatformRunStatus();
    snapshot.found = true;
    snapshot.status = status;
    snapshot.methodsEnqueued = enqueued;
    snapshot.methodsCompleted = completed;
    snapshot.methodsFailed = failed;
    return snapshot;
  }

  private static Integer getScheduleAttemptCount() {
    return TestMonitoringService.scheduleAttemptCount;
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

  private static Test_Run__c insertRun(
    Id scheduleId,
    String status,
    Datetime startedDate
  ) {
    Test_Run__c run = new Test_Run__c(
      Test_Schedule__c = scheduleId,
      Status__c = status,
      Started_Date__c = startedDate,
      Async_Apex_Job_Id__c = '707000000000001',
      Notification_Recipients__c = 'admin@example.com'
    );
    insert run;
    return run;
  }

  @isTest
  static void checkStatus_emailRejected_keepsCompletedRunAndCapturesFailure() {
    Test_Schedule__c schedule = insertSchedule();
    Test_Run__c run = insertRun(schedule.Id, 'Queued', Datetime.now());
    FakePlatformTestRunGateway platform = new FakePlatformTestRunGateway();
    platform.statusToReturn = buildStatus('Completed', 10, 10, 10, 0);
    FakeEmailGateway email = new FakeEmailGateway();
    email.throwOnSend = true;
    buildService(platform, new FakeCoverageGateway(), email)
      .checkStatus(run.Id);
    Test_Run__c updated = [
      SELECT Status__c, Notification_Sent__c, Summary__c
      FROM Test_Run__c
      WHERE Id = :run.Id
    ];
    System.assertEquals('Completed', updated.Status__c);
    System.assertEquals(false, updated.Notification_Sent__c);
    System.assert(
      updated.Summary__c.contains(
        'Notification not sent: Simulated email send failure.'
      )
    );
  }

  @isTest
  static void recoverStaleRuns_emailRejected_keepsResultsAndNoFalseSentFlags() {
    Test_Schedule__c schedule = insertSchedule();
    Test_Run__c first = insertRun(
      schedule.Id,
      'Queued',
      Datetime.now().addMinutes(-300)
    );
    Test_Run__c second = insertRun(
      schedule.Id,
      'Queued',
      Datetime.now().addMinutes(-300)
    );
    FakeEmailGateway email = new FakeEmailGateway();
    email.throwOnSend = true;
    buildService(
        new FakePlatformTestRunGateway(),
        new FakeCoverageGateway(),
        email
      )
      .recoverStaleRuns();
    for (Test_Run__c run : [
      SELECT Status__c, Notification_Sent__c, Summary__c
      FROM Test_Run__c
      WHERE Test_Schedule__c = :schedule.Id
    ]) {
      System.assertEquals('Failed', run.Status__c);
      System.assertEquals(false, run.Notification_Sent__c);
      System.assert(
        run.Summary__c.contains(
          'Notification not sent: Simulated email send failure.'
        )
      );
    }
  }
}
