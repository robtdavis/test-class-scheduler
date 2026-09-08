/**
 * Test double for ITestRunGateway that records the classIds it was asked to enqueue instead of
 * performing the real (test-incompatible) ApexTestQueueItem insert.
 */
@isTest
public class FakeTestRunGateway implements ITestRunGateway {
  public Set<Id> lastEnqueuedClassIds;
  public Integer invocationCount = 0;
  public String jobIdToReturn = '707FAKE00000000AAA';

  public String enqueueClasses(Set<Id> classIds) {
    invocationCount++;
    lastEnqueuedClassIds = classIds;
    return jobIdToReturn;
  }
}
