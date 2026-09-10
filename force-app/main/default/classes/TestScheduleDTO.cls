/**
 * Data shape exchanged with the LWC for a single Test_Schedule__c: configuration in, and the
 * saved/computed state (cron expression, job id, captured time zone) out.
 * Run time is represented as separate hour/minute integers rather than an Apex Time to keep the
 * wire format unambiguous for the LWC's plain HTML time input.
 */
public class TestScheduleDTO {
  @AuraEnabled
  public String scheduleName { get; set; }
  @AuraEnabled
  public String jobState { get; set; }
  @AuraEnabled
  public Datetime nextRun { get; set; }
  @AuraEnabled
  public Datetime previousRun { get; set; }
  @AuraEnabled
  public Id scheduleId { get; set; }
  @AuraEnabled
  public Boolean active { get; set; }
  @AuraEnabled
  public Boolean runAllTests { get; set; }
  @AuraEnabled
  public Integer runTimeHour { get; set; }
  @AuraEnabled
  public Integer runTimeMinute { get; set; }
  @AuraEnabled
  public String timeZone { get; set; }
  @AuraEnabled
  public Boolean sunday { get; set; }
  @AuraEnabled
  public Boolean monday { get; set; }
  @AuraEnabled
  public Boolean tuesday { get; set; }
  @AuraEnabled
  public Boolean wednesday { get; set; }
  @AuraEnabled
  public Boolean thursday { get; set; }
  @AuraEnabled
  public Boolean friday { get; set; }
  @AuraEnabled
  public Boolean saturday { get; set; }
  @AuraEnabled
  public String notificationRecipients { get; set; }
  @AuraEnabled
  public String cronExpression { get; set; }
  @AuraEnabled
  public String cronJobId { get; set; }
  @AuraEnabled
  public List<Id> selectedClassIds { get; set; }

  public TestScheduleDTO() {
    selectedClassIds = new List<Id>();
  }
}
