@isTest
private class TestSchedulerScaleTest {
  @testSetup
  static void setup() {
    TestSchedulerTestUtils.assignAdminPermissionSet();
  }

  /**
   * Bulk-safe DAO/service behavior: saveSchedule must insert all selected-class junctions in a
   * single DML statement regardless of how many classes are selected. Uses however many ApexClass
   * rows exist in the org (up to 200) rather than hard-requiring exactly 200, so the test is
   * portable across orgs with fewer deployed classes.
   */
  @isTest
  static void saveSchedule_manySelectedClasses_bulkInsertsAllJunctions() {
    List<Id> classIds = new List<Id>();
    for (ApexClass cls : [SELECT Id FROM ApexClass LIMIT 200]) {
      classIds.add(cls.Id);
    }
    System.assert(
      !classIds.isEmpty(),
      'Expected at least one ApexClass in the org to run this test'
    );

    TestScheduleDTO input = new TestScheduleDTO();
    input.active = false;
    input.runAllTests = false;
    input.runTimeHour = 8;
    input.runTimeMinute = 0;
    input.monday = true;
    input.notificationRecipients = 'admin@example.com';
    input.selectedClassIds = classIds;

    Test.startTest();
    TestScheduleDTO saved = new TestSchedulerService().saveSchedule(input);
    Test.stopTest();

    System.assertEquals(classIds.size(), saved.selectedClassIds.size());
    System.assertEquals(
      classIds.size(),
      [
        SELECT COUNT()
        FROM Test_Schedule_Class__c
        WHERE Test_Schedule__c = :saved.scheduleId
      ]
    );
  }

  /** Replacing an existing large selection (delete + reinsert) must also stay bulk-safe. */
  @isTest
  static void saveSchedule_replacingManySelectedClasses_bulkDeletesAndReinserts() {
    List<Id> classIds = new List<Id>();
    for (ApexClass cls : [SELECT Id FROM ApexClass LIMIT 200]) {
      classIds.add(cls.Id);
    }

    TestScheduleDTO input = new TestScheduleDTO();
    input.active = false;
    input.runAllTests = false;
    input.runTimeHour = 8;
    input.runTimeMinute = 0;
    input.monday = true;
    input.notificationRecipients = 'admin@example.com';
    input.selectedClassIds = classIds;

    Test.startTest();
    TestScheduleDTO first = new TestSchedulerService().saveSchedule(input);

    TestScheduleDTO revised = new TestScheduleDTO();
    revised.scheduleId = first.scheduleId;
    revised.active = false;
    revised.runAllTests = true;
    revised.runTimeHour = 8;
    revised.runTimeMinute = 0;
    revised.monday = true;
    revised.notificationRecipients = 'admin@example.com';
    revised.selectedClassIds = new List<Id>();
    TestScheduleDTO second = new TestSchedulerService().saveSchedule(revised);
    Test.stopTest();

    System.assertEquals(
      0,
      [
        SELECT COUNT()
        FROM Test_Schedule_Class__c
        WHERE Test_Schedule__c = :second.scheduleId
      ],
      'Switching to Run All Tests should remove all previously selected junctions'
    );
  }
}
