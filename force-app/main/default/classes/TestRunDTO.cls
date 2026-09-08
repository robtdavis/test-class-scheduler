/**
 * Summary of a single Test_Run__c for display in the LWC (latest status / recent history).
 */
public class TestRunDTO {
  @AuraEnabled
  public Id runId;
  @AuraEnabled
  public String status;
  @AuraEnabled
  public Boolean isAllTests;
  @AuraEnabled
  public Datetime startedDate;
  @AuraEnabled
  public Datetime completedDate;
  @AuraEnabled
  public Integer totalTests;
  @AuraEnabled
  public Integer passedTests;
  @AuraEnabled
  public Integer failedTests;
  @AuraEnabled
  public String summary;
  @AuraEnabled
  public String failureDetails;

  public static TestRunDTO fromRecord(Test_Run__c run) {
    if (run == null) {
      return null;
    }
    TestRunDTO dto = new TestRunDTO();
    dto.runId = run.Id;
    dto.status = run.Status__c;
    dto.isAllTests = run.Is_All_Tests__c;
    dto.startedDate = run.Started_Date__c;
    dto.completedDate = run.Completed_Date__c;
    dto.totalTests = (Integer) run.Total_Tests__c;
    dto.passedTests = (Integer) run.Passed_Tests__c;
    dto.failedTests = (Integer) run.Failed_Tests__c;
    dto.summary = run.Summary__c;
    dto.failureDetails = run.Failure_Details__c;
    return dto;
  }
}
