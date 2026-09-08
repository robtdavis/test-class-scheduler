/**
 * Read-only access to ApexClass metadata for discovering runnable Apex test classes.
 * ApexClass is a system/metadata object (not row-level shared like a custom object), and access to
 * it is already gated by the "View Setup and Configuration" permission required to use this feature
 * at all, so WITH SECURITY_ENFORCED / USER_MODE is not applied here.
 * ApexClass.Body cannot be filtered in a SOQL WHERE clause, so all classes' bodies are retrieved and
 * the @isTest/testMethod match is applied in Apex.
 * Selectors must not call services or controllers.
 */
public inherited sharing class TestClassSelector {
  private static final Integer MAX_RESULTS = 200;

  /**
   * Returns Apex test classes (classes whose body contains @isTest or the legacy testMethod
   * keyword), optionally filtered by a case-insensitive name search term.
   */
  public List<ApexClass> getTestClasses(String searchTerm) {
    String namePattern =
      '%' +
      String.escapeSingleQuotes(String.isBlank(searchTerm) ? '' : searchTerm) +
      '%';
    List<ApexClass> matches = new List<ApexClass>();
    for (ApexClass cls : [
      SELECT Id, Name, Body
      FROM ApexClass
      WHERE Name LIKE :namePattern
      ORDER BY Name ASC
    ]) {
      if (isTestClass(cls) && matches.size() < MAX_RESULTS) {
        matches.add(cls);
      }
    }
    return matches;
  }

  /**
   * Returns all Apex test class Ids in the org, used when a schedule is configured to run all tests.
   */
  public List<ApexClass> getAllTestClasses() {
    List<ApexClass> matches = new List<ApexClass>();
    for (ApexClass cls : [
      SELECT Id, Name, Body
      FROM ApexClass
      ORDER BY Name ASC
    ]) {
      if (isTestClass(cls)) {
        matches.add(cls);
      }
    }
    return matches;
  }

  /**
   * Returns the Id/Name for a specific set of ApexClass Ids, used to validate selections on save.
   */
  public List<ApexClass> getClassesByIds(Set<Id> classIds) {
    if (classIds == null || classIds.isEmpty()) {
      return new List<ApexClass>();
    }
    return [SELECT Id, Name FROM ApexClass WHERE Id IN :classIds];
  }

  private Boolean isTestClass(ApexClass cls) {
    if (cls.Body == null) {
      return false;
    }
    String lowerBody = cls.Body.toLowerCase();
    return lowerBody.contains('@istest') || lowerBody.contains('testmethod');
  }
}
