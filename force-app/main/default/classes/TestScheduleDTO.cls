/**
 * Data shape exchanged with the LWC for a single Test_Schedule__c: configuration in, and the
 * saved/computed state (cron expression, job id, captured time zone) out.
 * Run time is represented as separate hour/minute integers rather than an Apex Time to keep the
 * wire format unambiguous for the LWC's plain HTML time input.
 */
public class TestScheduleDTO {
  @AuraEnabled
  public Id scheduleId;
  @AuraEnabled
  public Boolean active;
  @AuraEnabled
  public Boolean runAllTests;
  @AuraEnabled
  public Integer runTimeHour;
  @AuraEnabled
  public Integer runTimeMinute;
  @AuraEnabled
  public String timeZone;
  @AuraEnabled
  public Boolean sunday;
  @AuraEnabled
  public Boolean monday;
  @AuraEnabled
  public Boolean tuesday;
  @AuraEnabled
  public Boolean wednesday;
  @AuraEnabled
  public Boolean thursday;
  @AuraEnabled
  public Boolean friday;
  @AuraEnabled
  public Boolean saturday;
  @AuraEnabled
  public String notificationRecipients;
  @AuraEnabled
  public String cronExpression;
  @AuraEnabled
  public String cronJobId;
  @AuraEnabled
  public List<Id> selectedClassIds = new List<Id>();
}
