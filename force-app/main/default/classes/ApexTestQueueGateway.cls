/**
 * Real ApexTestQueueItem-backed implementation of ITestRunGateway (see TestExecutionService for the
 * platform rationale). Salesforce does not allow ApexTestQueueItem inserts while an Apex test is
 * executing ("Apex tests cannot be enqueued during a test."), which would otherwise make it
 * impossible to unit test schedule activation (System.schedule's Test.stopTest() behavior runs the
 * scheduled job - and therefore this code - synchronously inside the very test exercising it). That
 * is a genuine platform restriction, not a design choice, so it is handled here explicitly rather
 * than concealed: in test context a synthetic job id is returned instead of performing the insert.
 */
public class ApexTestQueueGateway implements ITestRunGateway {
  public String enqueueClasses(Set<Id> classIds) {
    if (Test.isRunningTest()) {
      return '707TEST0000000FAKE';
    }
    List<ApexTestQueueItem> queueItems = new List<ApexTestQueueItem>();
    for (Id classId : classIds) {
      queueItems.add(
        new ApexTestQueueItem(
          ApexClassId = classId,
          ShouldSkipCodeCoverage = false
        )
      );
    }
    insert queueItems;
    return [
      SELECT ParentJobId
      FROM ApexTestQueueItem
      WHERE Id = :queueItems[0].Id
      LIMIT 1
    ]
    .ParentJobId;
  }
}
