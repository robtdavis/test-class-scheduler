/** Test double for IPlatformTestRunGateway; returns canned, configurable data. */
@isTest
public class FakePlatformTestRunGateway implements IPlatformTestRunGateway {
  public PlatformRunStatus statusToReturn = new PlatformRunStatus();
  public List<FailedTestInfo> failuresToReturn = new List<FailedTestInfo>();

  public PlatformRunStatus getRunStatus(String asyncApexJobId) {
    return statusToReturn;
  }

  public List<FailedTestInfo> getFailedResults(String asyncApexJobId) {
    return failuresToReturn;
  }
}
