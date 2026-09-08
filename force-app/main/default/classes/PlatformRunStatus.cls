/** Point-in-time snapshot of ApexTestRunResult for a single test run. */
public class PlatformRunStatus {
  public Boolean found = false;
  public String status;
  public Integer classesCompleted = 0;
  public Integer classesEnqueued = 0;
  public Integer methodsCompleted = 0;
  public Integer methodsEnqueued = 0;
  public Integer methodsFailed = 0;

  public Boolean isTerminal() {
    return status == 'Completed' || status == 'Failed' || status == 'Aborted';
  }
}
