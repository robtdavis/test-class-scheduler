/** Real implementation delegating the actual SOQL to TestRunSelector/TestClassSelector. */
public with sharing class RealPlatformTestRunGateway implements IPlatformTestRunGateway {
  private final TestRunSelector runSelector = new TestRunSelector();
  private final TestClassSelector classSelector = new TestClassSelector();

  public PlatformRunStatus getRunStatus(String asyncApexJobId) {
    ApexTestRunResult result = runSelector.getApexTestRunResult(asyncApexJobId);
    PlatformRunStatus snapshot = new PlatformRunStatus();
    if (result == null) {
      return snapshot;
    }
    snapshot.found = true;
    snapshot.status = result.Status;
    snapshot.classesCompleted = (Integer) result.ClassesCompleted;
    snapshot.classesEnqueued = (Integer) result.ClassesEnqueued;
    snapshot.methodsCompleted = (Integer) result.MethodsCompleted;
    snapshot.methodsEnqueued = (Integer) result.MethodsEnqueued;
    snapshot.methodsFailed = (Integer) result.MethodsFailed;
    return snapshot;
  }

  public List<FailedTestInfo> getFailedResults(String asyncApexJobId) {
    List<ApexTestResult> failures = runSelector.getFailedApexTestResults(
      asyncApexJobId
    );
    Set<Id> classIds = new Set<Id>();
    for (ApexTestResult failure : failures) {
      classIds.add(failure.ApexClassId);
    }
    Map<Id, ApexClass> classesById = new Map<Id, ApexClass>(
      classSelector.getClassesByIds(classIds)
    );

    List<FailedTestInfo> infos = new List<FailedTestInfo>();
    for (ApexTestResult failure : failures) {
      FailedTestInfo info = new FailedTestInfo();
      ApexClass cls = classesById.get(failure.ApexClassId);
      info.className = cls != null
        ? cls.Name
        : String.valueOf(failure.ApexClassId);
      info.methodName = failure.MethodName;
      info.message = failure.Message;
      info.stackTrace = failure.StackTrace;
      infos.add(info);
    }
    return infos;
  }
}
