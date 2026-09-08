/**
 * Calculates and formats Apex test run execution summaries for display/notification. Pure
 * formatting logic only - no SOQL, DML, or callouts, so no gateway/DI seam is needed here.
 */
public with sharing class TestResultService {
  public String buildSummaryText(Test_Run__c run, Decimal coveragePercent) {
    Boolean success =
      run.Status__c == 'Completed' &&
      (run.Failed_Tests__c == null ||
      run.Failed_Tests__c == 0);
    List<String> lines = new List<String>();
    lines.add('Apex Test Scheduler run: ' + (success ? 'SUCCESS' : 'FAILURE'));
    lines.add('Status: ' + run.Status__c);
    lines.add('Started: ' + formatDatetime(run.Started_Date__c));
    lines.add('Completed: ' + formatDatetime(run.Completed_Date__c));
    lines.add(
      'Total / Passed / Failed: ' +
        defaultToZero(run.Total_Tests__c) +
        ' / ' +
        defaultToZero(run.Passed_Tests__c) +
        ' / ' +
        defaultToZero(run.Failed_Tests__c)
    );
    lines.add(
      coveragePercent != null
        ? 'Org-wide code coverage: ' + coveragePercent + '%'
        : 'Org-wide code coverage: unavailable (Tooling API access not configured)'
    );
    return String.join(lines, '\n');
  }

  /** Only failing methods are included - passing methods aren't persisted per MVP scope. */
  public String buildFailureDetailsText(List<FailedTestInfo> failures) {
    if (failures == null || failures.isEmpty()) {
      return '';
    }
    List<String> blocks = new List<String>();
    for (FailedTestInfo failure : failures) {
      List<String> lines = new List<String>();
      lines.add(failure.className + '.' + failure.methodName);
      if (String.isNotBlank(failure.message)) {
        lines.add('Message: ' + failure.message);
      }
      if (String.isNotBlank(failure.stackTrace)) {
        lines.add('Stack trace: ' + failure.stackTrace);
      }
      blocks.add(String.join(lines, '\n'));
    }
    return String.join(blocks, '\n---\n');
  }

  private String formatDatetime(Datetime value) {
    return value == null ? 'n/a' : value.format('yyyy-MM-dd HH:mm:ss');
  }

  private Decimal defaultToZero(Decimal value) {
    return value == null ? 0 : value;
  }
}
