/**
 * Aura-enabled entry point for the apexTestScheduler LWC. Validates requests, invokes services, and
 * returns DTOs - no SOQL and no scheduling/business logic here.
 */
public with sharing class TestSchedulerController {
  @AuraEnabled
  public static List<TestClassOptionDTO> getTestClassOptions(
    String searchTerm
  ) {
    try {
      List<TestClassOptionDTO> options = new List<TestClassOptionDTO>();
      for (ApexClass cls : new TestClassSelector().getTestClasses(searchTerm)) {
        options.add(new TestClassOptionDTO(cls.Id, cls.Name));
      }
      return options;
    } catch (Exception ex) {
      throw wrap(ex);
    }
  }

  @AuraEnabled
  public static TestScheduleDTO getScheduleConfiguration() {
    try {
      List<Test_Schedule__c> schedules = new TestRunSelector()
        .getAllSchedules();
      if (schedules.isEmpty()) {
        return null;
      }
      return toDto(schedules[0]);
    } catch (Exception ex) {
      throw wrap(ex);
    }
  }

  @AuraEnabled
  public static List<TestScheduleDTO> getSchedules() {
    try {
      TestRunSelector selector = new TestRunSelector();
      List<Test_Schedule__c> records = selector.getAllSchedules();
      Set<Id> scheduleIds = new Map<Id, Test_Schedule__c>(records).keySet();
      Set<Id> triggerIds = new Set<Id>();
      Map<Id, List<Id>> classes = new Map<Id, List<Id>>();
      for (Test_Schedule__c record : records) {
        classes.put(record.Id, new List<Id>());
        if (String.isNotBlank(record.Cron_Job_Id__c))
          triggerIds.add((Id) record.Cron_Job_Id__c);
      }
      for (
        Test_Schedule_Class__c junction : selector.getClassesForSchedules(
          scheduleIds
        )
      ) {
        classes.get(junction.Test_Schedule__c)
          .add((Id) junction.Apex_Class_Id__c);
      }
      Map<Id, CronTrigger> triggers = selector.getScheduleTriggers(triggerIds);
      List<TestScheduleDTO> results = new List<TestScheduleDTO>();
      for (Test_Schedule__c record : records) {
        TestScheduleDTO dto = toDto(record, classes.get(record.Id));
        CronTrigger cronTrigger = String.isBlank(record.Cron_Job_Id__c)
          ? null
          : triggers.get((Id) record.Cron_Job_Id__c);
        dto.jobState = !record.Active__c
          ? 'Inactive'
          : cronTrigger == null ? 'Missing job' : cronTrigger.State;
        if (cronTrigger != null) {
          dto.nextRun = cronTrigger.NextFireTime;
          dto.previousRun = cronTrigger.PreviousFireTime;
          dto.timeZone = cronTrigger.TimeZoneSidKey;
        }
        results.add(dto);
      }
      return results;
    } catch (Exception ex) {
      throw wrap(ex);
    }
  }

  @AuraEnabled
  public static TestScheduleDTO saveSchedule(TestScheduleDTO scheduleInput) {
    try {
      return new TestSchedulerService().saveSchedule(scheduleInput);
    } catch (Exception ex) {
      throw wrap(ex);
    }
  }

  @AuraEnabled
  public static void deactivateSchedule(Id scheduleId) {
    try {
      new TestSchedulerService().deactivateSchedule(scheduleId);
    } catch (Exception ex) {
      throw wrap(ex);
    }
  }

  @AuraEnabled
  public static void deleteSchedule(Id scheduleId) {
    try {
      new TestSchedulerService().deleteSchedule(scheduleId);
    } catch (Exception ex) {
      throw wrap(ex);
    }
  }

  @AuraEnabled
  public static TestRunDTO runNow(Id scheduleId) {
    try {
      Id runId = new TestExecutionService().runNow(scheduleId);
      return TestRunDTO.fromRecord(new TestRunSelector().getRunById(runId));
    } catch (Exception ex) {
      throw wrap(ex);
    }
  }

  @AuraEnabled
  public static TestRunDTO getLatestRun(Id scheduleId) {
    try {
      return TestRunDTO.fromRecord(
        new TestRunSelector().getLatestRun(scheduleId)
      );
    } catch (Exception ex) {
      throw wrap(ex);
    }
  }

  @AuraEnabled
  public static List<TestRunDTO> getRecentRuns(
    Id scheduleId,
    Integer maxResults
  ) {
    try {
      List<TestRunDTO> results = new List<TestRunDTO>();
      for (
        Test_Run__c run : new TestRunSelector()
          .getRecentRuns(scheduleId, maxResults)
      ) {
        results.add(TestRunDTO.fromRecord(run));
      }
      return results;
    } catch (Exception ex) {
      throw wrap(ex);
    }
  }

  private static TestScheduleDTO toDto(Test_Schedule__c record) {
    List<Id> classIds = new List<Id>();
    for (
      Test_Schedule_Class__c junction : new TestRunSelector()
        .getSelectedClasses(record.Id)
    ) {
      classIds.add((Id) junction.Apex_Class_Id__c);
    }
    return toDto(record, classIds);
  }

  private static TestScheduleDTO toDto(
    Test_Schedule__c record,
    List<Id> classIds
  ) {
    // Delegates field mapping to the service, which already builds this DTO shape on save.
    TestScheduleDTO dto = new TestScheduleDTO();
    dto.scheduleId = record.Id;
    dto.scheduleName = record.Name;
    dto.active = record.Active__c;
    dto.runAllTests = record.Run_All_Tests__c;
    dto.runTimeHour = record.Run_Time__c != null
      ? record.Run_Time__c.hour()
      : null;
    dto.runTimeMinute = record.Run_Time__c != null
      ? record.Run_Time__c.minute()
      : null;
    dto.timeZone = record.Time_Zone__c;
    dto.sunday = record.Sunday__c;
    dto.monday = record.Monday__c;
    dto.tuesday = record.Tuesday__c;
    dto.wednesday = record.Wednesday__c;
    dto.thursday = record.Thursday__c;
    dto.friday = record.Friday__c;
    dto.saturday = record.Saturday__c;
    dto.notificationRecipients = record.Notification_Recipients__c;
    dto.cronExpression = record.Cron_Expression__c;
    dto.cronJobId = record.Cron_Job_Id__c;
    dto.selectedClassIds = classIds;
    return dto;
  }

  private static AuraHandledException wrap(Exception ex) {
    AuraHandledException wrapped = new AuraHandledException(ex.getMessage());
    wrapped.setMessage(ex.getMessage());
    return wrapped;
  }
}
