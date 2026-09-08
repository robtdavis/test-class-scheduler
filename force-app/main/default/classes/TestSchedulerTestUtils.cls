@isTest
public class TestSchedulerTestUtils {
  /**
   * Assigns the Test_Scheduler_Admin permission set to the running user so USER_MODE SOQL/DML in
   * the selectors and services used by these tests have the field-level access they need.
   */
  public static void assignAdminPermissionSet() {
    Id permissionSetId = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = 'Test_Scheduler_Admin'
      LIMIT 1
    ]
    .Id;
    Boolean alreadyAssigned = ![
        SELECT Id
        FROM PermissionSetAssignment
        WHERE
          AssigneeId = :UserInfo.getUserId()
          AND PermissionSetId = :permissionSetId
      ]
      .isEmpty();
    if (!alreadyAssigned) {
      insert new PermissionSetAssignment(
        AssigneeId = UserInfo.getUserId(),
        PermissionSetId = permissionSetId
      );
    }
  }
}
