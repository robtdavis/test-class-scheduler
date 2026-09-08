/**
 * Narrow seam around the platform's own ApexTestRunResult/ApexTestResult data. Their data can't be
 * fabricated in a unit test (Salesforce only populates them from a real, completed test run, which
 * can't be triggered inside a test - the same class of restriction as ApexTestQueueItem inserts),
 * so TestMonitoringService depends on this interface instead of TestRunSelector's platform-object
 * methods directly, keeping it unit-testable with a fake.
 */
public interface IPlatformTestRunGateway {
  PlatformRunStatus getRunStatus(String asyncApexJobId);
  List<FailedTestInfo> getFailedResults(String asyncApexJobId);
}
