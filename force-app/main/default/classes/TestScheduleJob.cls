/**
 * Schedulable entry point invoked by the CRON job created in TestSchedulerService. Kept minimal -
 * all real work is delegated to TestExecutionService, per the recommendation to avoid heavy logic
 * directly in the execute() method.
 */
public without sharing class TestScheduleJob implements Schedulable {
  private final Id scheduleId;

  public TestScheduleJob(Id scheduleId) {
    this.scheduleId = scheduleId;
  }

  public void execute(SchedulableContext sc) {
    try {
      new TestExecutionService().startScheduledRun(scheduleId);
    } catch (TestExecutionService.TestExecutionException ex) {
      // A scheduled fire landing while a previous run is still active/queued (or a
      // no-longer-valid schedule) is skipped rather than surfaced as an unhandled scheduled
      // Apex exception (which Salesforce would otherwise email to the job owner); the next
      // scheduled fire will try again.
    }
  }
}
