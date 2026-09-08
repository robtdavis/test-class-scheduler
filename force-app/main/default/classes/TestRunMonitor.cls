/**
 * Thin Schedulable entry point for a single poll of an in-flight test run; all logic (including
 * deciding whether/when to reschedule) lives in TestMonitoringService.
 */
public without sharing class TestRunMonitor implements Schedulable {
  private final Id testRunId;

  public TestRunMonitor(Id testRunId) {
    this.testRunId = testRunId;
  }

  public void execute(SchedulableContext sc) {
    new TestMonitoringService().checkStatus(testRunId);
  }
}
