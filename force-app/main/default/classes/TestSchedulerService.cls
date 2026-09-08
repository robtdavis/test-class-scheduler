/**
 * Schedule creation, update, deactivation, and deletion for Test_Schedule__c, including
 * weekday/time -> Salesforce CRON conversion and CronTrigger lifecycle management.
 * Note: System.schedule() runs a CRON expression in the TIME ZONE OF THE CALLING USER - Salesforce
 * does not support scheduling a job in an arbitrary, independently selectable time zone. Time_Zone__c
 * is therefore captured automatically from the saving user (UserInfo.getTimeZone()) and is
 * informational/display-only, not a free picklist implying otherwise.
 */
public with sharing class TestSchedulerService {
  @TestVisible
  private static final String JOB_NAME_PREFIX = 'TestSchedule_';
  // Salesforce hard limit on concurrently scheduled Apex (CronTrigger) jobs, org-wide.
  @TestVisible
  private static final Integer MAX_SCHEDULED_APEX_JOBS = 100;

  private final TestRunSelector runSelector = new TestRunSelector();
  private final TestClassSelector classSelector = new TestClassSelector();

  /**
   * Builds a Salesforce CRON expression covering every selected weekday at the given time.
   * A single CRON expression can list multiple days (e.g. "0 0 8 ? * MON,WED,FRI *"), so one
   * CronTrigger per schedule always suffices - never one job per day or per test method.
   */
  public String buildCronExpression(
    Integer hour,
    Integer minute,
    Boolean sunday,
    Boolean monday,
    Boolean tuesday,
    Boolean wednesday,
    Boolean thursday,
    Boolean friday,
    Boolean saturday
  ) {
    if (hour == null || hour < 0 || hour > 23) {
      throw new TestSchedulerException(
        'Run time hour must be between 0 and 23.'
      );
    }
    if (minute == null || minute < 0 || minute > 59) {
      throw new TestSchedulerException(
        'Run time minute must be between 0 and 59.'
      );
    }

    List<String> days = new List<String>();
    if (sunday == true) {
      days.add('SUN');
    }
    if (monday == true) {
      days.add('MON');
    }
    if (tuesday == true) {
      days.add('TUE');
    }
    if (wednesday == true) {
      days.add('WED');
    }
    if (thursday == true) {
      days.add('THU');
    }
    if (friday == true) {
      days.add('FRI');
    }
    if (saturday == true) {
      days.add('SAT');
    }
    if (days.isEmpty()) {
      throw new TestSchedulerException('Select at least one day of the week.');
    }

    return '0 ' + minute + ' ' + hour + ' ? * ' + String.join(days, ',');
  }

  public TestScheduleDTO saveSchedule(TestScheduleDTO input) {
    if (input == null) {
      throw new TestSchedulerException('Schedule data is required.');
    }
    validateRecipients(input.notificationRecipients);
    if (
      input.runAllTests != true &&
      (input.selectedClassIds == null || input.selectedClassIds.isEmpty())
    ) {
      throw new TestSchedulerException(
        'Select at least one Apex test class, or choose Run All Tests.'
      );
    }

    String cron = buildCronExpression(
      input.runTimeHour,
      input.runTimeMinute,
      input.sunday,
      input.monday,
      input.tuesday,
      input.wednesday,
      input.thursday,
      input.friday,
      input.saturday
    );

    Test_Schedule__c existing = input.scheduleId != null
      ? runSelector.getScheduleById(input.scheduleId)
      : getSingletonSchedule();

    Test_Schedule__c record = existing != null
      ? existing
      : new Test_Schedule__c();
    record.Active__c = input.active == true;
    record.Run_Time__c = Time.newInstance(
      input.runTimeHour,
      input.runTimeMinute,
      0,
      0
    );
    record.Run_All_Tests__c = input.runAllTests == true;
    record.Sunday__c = input.sunday == true;
    record.Monday__c = input.monday == true;
    record.Tuesday__c = input.tuesday == true;
    record.Wednesday__c = input.wednesday == true;
    record.Thursday__c = input.thursday == true;
    record.Friday__c = input.friday == true;
    record.Saturday__c = input.saturday == true;
    record.Notification_Recipients__c = input.notificationRecipients;
    record.Cron_Expression__c = cron;

    String previousJobId = record.Cron_Job_Id__c;
    upsertSchedule(record);

    replaceSelectedClasses(
      record.Id,
      input.runAllTests == true ? null : input.selectedClassIds
    );

    abortJobIfPresent(previousJobId);
    record.Cron_Job_Id__c = null;
    record.Time_Zone__c = null;

    if (record.Active__c) {
      record.Cron_Job_Id__c = scheduleJob(record.Id, cron);
      record.Time_Zone__c = UserInfo.getTimeZone().getID();
    }
    upsertSchedule(record);

    return toDto(record);
  }

  public void deactivateSchedule(Id scheduleId) {
    Test_Schedule__c record = requireSchedule(scheduleId);
    abortJobIfPresent(record.Cron_Job_Id__c);
    record.Active__c = false;
    record.Cron_Job_Id__c = null;
    upsertSchedule(record);
  }

  public void deleteSchedule(Id scheduleId) {
    Test_Schedule__c record = requireSchedule(scheduleId);
    abortJobIfPresent(record.Cron_Job_Id__c);
    Database.delete(
      new List<Test_Schedule__c>{ record },
      AccessLevel.USER_MODE
    );
  }

  private Test_Schedule__c requireSchedule(Id scheduleId) {
    Test_Schedule__c record = runSelector.getScheduleById(scheduleId);
    if (record == null) {
      throw new TestSchedulerException('Schedule not found.');
    }
    return record;
  }

  /**
   * MVP supports a single, org-wide schedule (multi-schedule management is out of scope for this
   * increment); this returns that schedule if one already exists, so saving always updates it
   * instead of creating duplicates.
   */
  private Test_Schedule__c getSingletonSchedule() {
    List<Test_Schedule__c> all = runSelector.getAllSchedules();
    return all.isEmpty() ? null : all[0];
  }

  private void upsertSchedule(Test_Schedule__c record) {
    Database.upsert(
      new List<Test_Schedule__c>{ record },
      AccessLevel.USER_MODE
    );
  }

  private void replaceSelectedClasses(
    Id scheduleId,
    List<Id> selectedClassIds
  ) {
    List<Test_Schedule_Class__c> existing = runSelector.getSelectedClasses(
      scheduleId
    );
    if (!existing.isEmpty()) {
      Database.delete(existing, AccessLevel.USER_MODE);
    }
    if (selectedClassIds == null || selectedClassIds.isEmpty()) {
      return;
    }
    Map<Id, ApexClass> classesById = new Map<Id, ApexClass>(
      classSelector.getClassesByIds(new Set<Id>(selectedClassIds))
    );
    List<Test_Schedule_Class__c> junctions = new List<Test_Schedule_Class__c>();
    for (Id classId : selectedClassIds) {
      ApexClass cls = classesById.get(classId);
      if (cls == null) {
        continue;
      }
      junctions.add(
        new Test_Schedule_Class__c(
          Test_Schedule__c = scheduleId,
          Apex_Class_Id__c = cls.Id,
          Apex_Class_Name__c = cls.Name
        )
      );
    }
    if (!junctions.isEmpty()) {
      Database.insert(junctions, AccessLevel.USER_MODE);
    }
  }

  private String scheduleJob(Id scheduleId, String cron) {
    Integer scheduledApexJobCount = [
      SELECT COUNT()
      FROM CronTrigger
      WHERE CronJobDetail.JobType = '7'
      WITH USER_MODE
    ];
    if (scheduledApexJobCount >= MAX_SCHEDULED_APEX_JOBS) {
      throw new TestSchedulerException(
        'Cannot activate schedule: the org has reached the maximum of ' +
          MAX_SCHEDULED_APEX_JOBS +
          ' scheduled Apex jobs.'
      );
    }
    String jobName = JOB_NAME_PREFIX + scheduleId;
    try {
      return System.schedule(jobName, cron, new TestScheduleJob(scheduleId));
    } catch (Exception ex) {
      throw new TestSchedulerException(
        'Unable to schedule test run: ' + ex.getMessage()
      );
    }
  }

  private void abortJobIfPresent(String cronJobId) {
    if (String.isBlank(cronJobId)) {
      return;
    }
    try {
      System.abortJob(cronJobId);
    } catch (Exception ex) {
      // Job may have already completed/been removed; nothing to clean up in that case.
    }
  }

  private void validateRecipients(String recipients) {
    if (String.isBlank(recipients)) {
      throw new TestSchedulerException(
        'At least one notification recipient email is required.'
      );
    }
    for (String address : recipients.split(',')) {
      String trimmed = address.trim();
      if (!Pattern.matches('^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$', trimmed)) {
        throw new TestSchedulerException(
          'Invalid notification recipient email: ' + trimmed
        );
      }
    }
  }

  private TestScheduleDTO toDto(Test_Schedule__c record) {
    TestScheduleDTO dto = new TestScheduleDTO();
    dto.scheduleId = record.Id;
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
    List<Id> classIds = new List<Id>();
    for (
      Test_Schedule_Class__c junction : runSelector.getSelectedClasses(
        record.Id
      )
    ) {
      classIds.add((Id) junction.Apex_Class_Id__c);
    }
    dto.selectedClassIds = classIds;
    return dto;
  }

  public class TestSchedulerException extends Exception {
  }
}
