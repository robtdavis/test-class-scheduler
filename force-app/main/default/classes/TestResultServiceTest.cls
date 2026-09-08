@isTest
private class TestResultServiceTest {
  @isTest
  static void buildSummaryText_successfulRun_reportsSuccess() {
    Test_Run__c run = new Test_Run__c(
      Status__c = 'Completed',
      Started_Date__c = Datetime.newInstanceGmt(2026, 1, 1, 8, 0, 0),
      Completed_Date__c = Datetime.newInstanceGmt(2026, 1, 1, 8, 5, 0),
      Total_Tests__c = 10,
      Passed_Tests__c = 10,
      Failed_Tests__c = 0
    );

    String summary = new TestResultService().buildSummaryText(run, 88.5);

    System.assert(summary.contains('SUCCESS'));
    System.assert(summary.contains('10 / 10 / 0'));
    System.assert(summary.contains('88.5%'));
  }

  @isTest
  static void buildSummaryText_failedRun_reportsFailureAndMissingCoverage() {
    Test_Run__c run = new Test_Run__c(
      Status__c = 'Completed',
      Total_Tests__c = 10,
      Passed_Tests__c = 8,
      Failed_Tests__c = 2
    );

    String summary = new TestResultService().buildSummaryText(run, null);

    System.assert(summary.contains('FAILURE'));
    System.assert(summary.contains('unavailable'));
  }

  @isTest
  static void buildSummaryText_nullCounts_defaultToZero() {
    Test_Run__c run = new Test_Run__c(Status__c = 'Failed');

    String summary = new TestResultService().buildSummaryText(run, null);

    System.assert(summary.contains('0 / 0 / 0'));
  }

  @isTest
  static void buildFailureDetailsText_empty_returnsEmptyString() {
    System.assertEquals(
      '',
      new TestResultService()
        .buildFailureDetailsText(new List<FailedTestInfo>())
    );
    System.assertEquals(
      '',
      new TestResultService().buildFailureDetailsText(null)
    );
  }

  @isTest
  static void buildFailureDetailsText_singleFailure_includesClassMethodMessageAndStack() {
    FailedTestInfo failure = new FailedTestInfo();
    failure.className = 'SomeTest';
    failure.methodName = 'testFoo';
    failure.message = 'Assertion failed';
    failure.stackTrace = 'Class.SomeTest.testFoo: line 5';

    String text = new TestResultService()
      .buildFailureDetailsText(new List<FailedTestInfo>{ failure });

    System.assert(text.contains('SomeTest.testFoo'));
    System.assert(text.contains('Assertion failed'));
    System.assert(text.contains('line 5'));
  }

  @isTest
  static void buildFailureDetailsText_manyFailures_scalesWithoutError() {
    List<FailedTestInfo> failures = new List<FailedTestInfo>();
    for (Integer i = 0; i < 200; i++) {
      FailedTestInfo failure = new FailedTestInfo();
      failure.className = 'BulkTest' + i;
      failure.methodName = 'testMethod' + i;
      failure.message = 'Failure number ' + i;
      failure.stackTrace =
        'Class.BulkTest' +
        i +
        '.testMethod' +
        i +
        ': line ' +
        i;
      failures.add(failure);
    }

    String text = new TestResultService().buildFailureDetailsText(failures);

    System.assert(text.contains('BulkTest0.testMethod0'));
    System.assert(text.contains('BulkTest199.testMethod199'));
  }
}
