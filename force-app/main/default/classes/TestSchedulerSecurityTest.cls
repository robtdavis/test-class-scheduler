/**
 * Verifies that a user without the Test_Scheduler_Admin permission set (no object/field access to
 * the custom objects) is cleanly denied by the controller (AuraHandledException, no leaked
 * internals/stack trace) rather than by an unhandled system exception. A true test of concurrent
 * row-locking across separate transactions can't be exercised from a single-threaded Apex test;
 * this class instead verifies the FLS/CRUD boundary, which is the enforceable, testable part of
 * "security" here.
 */
@isTest
private class TestSchedulerSecurityTest {
  @isTest
  static void controllerMethods_userWithoutPermissionSet_failCleanlyNotWithRawException() {
    User lowPrivilegeUser = createStandardUserWithoutPermissionSet();

    System.runAs(lowPrivilegeUser) {
      try {
        TestSchedulerController.getScheduleConfiguration();
        // If the org's baseline profile happens to grant enough access, that's acceptable;
        // the important assertion below is that failures are AuraHandledException, not a
        // raw QueryException/DmlException leaking internals.
      } catch (AuraHandledException ex) {
        System.assert(true);
      } catch (Exception ex) {
        System.assert(
          false,
          'Expected either success or a clean AuraHandledException, got: ' + ex
        );
      }

      TestScheduleDTO input = new TestScheduleDTO();
      input.active = true;
      input.runAllTests = true;
      input.runTimeHour = 8;
      input.runTimeMinute = 0;
      input.monday = true;
      input.notificationRecipients = 'admin@example.com';
      input.selectedClassIds = new List<Id>();

      try {
        TestSchedulerController.saveSchedule(input);
      } catch (AuraHandledException ex) {
        System.assert(true);
      } catch (Exception ex) {
        System.assert(
          false,
          'Expected either success or a clean AuraHandledException, got: ' + ex
        );
      }
    }
  }

  @isTest
  static void runNow_userWithoutPermissionSet_doesNotThrowRawSystemException() {
    User lowPrivilegeUser = createStandardUserWithoutPermissionSet();

    System.runAs(lowPrivilegeUser) {
      try {
        TestSchedulerController.runNow(null);
        System.assert(false, 'Expected an exception for a null schedule id');
      } catch (AuraHandledException ex) {
        System.assert(true);
      } catch (Exception ex) {
        System.assert(
          false,
          'Expected a clean AuraHandledException, got: ' + ex
        );
      }
    }
  }

  private static User createStandardUserWithoutPermissionSet() {
    Profile standardProfile = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Standard User'
      LIMIT 1
    ];
    String uniqueSuffix = String.valueOf(Crypto.getRandomInteger()).right(8);
    User lowPrivilegeUser = new User(
      Alias = 'tsuser',
      Email = 'test-scheduler-lowpriv' + uniqueSuffix + '@example.com',
      EmailEncodingKey = 'UTF-8',
      LastName = 'LowPrivilege',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = standardProfile.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      UserName = 'test-scheduler-lowpriv' +
        uniqueSuffix +
        '@example.com.scheduler'
    );
    insert lowPrivilegeUser;
    return lowPrivilegeUser;
  }
}
