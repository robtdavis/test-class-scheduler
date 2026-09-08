/**
 * Narrow seam around the mechanism used to enqueue Apex test execution, so TestExecutionService's
 * own logic (duplicate-run guard, run-all vs selected resolution, Test_Run__c creation) can be unit
 * tested with a fake, independent of the real ApexTestQueueItem side effect.
 */
public interface ITestRunGateway {
  /**
   * Enqueues the given Apex classes for asynchronous test execution and returns the shared
   * AsyncApexJobId (ApexTestQueueItem.ParentJobId) for the run.
   */
  String enqueueClasses(Set<Id> classIds);
}
