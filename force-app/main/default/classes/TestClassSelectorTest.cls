@isTest
private class TestClassSelectorTest {
  @isTest
  static void getTestClasses_findsKnownFixtureClasses() {
    TestClassSelector selector = new TestClassSelector();
    List<ApexClass> results = selector.getTestClasses('SchedulerFixtureTest');

    Set<String> names = new Set<String>();
    for (ApexClass cls : results) {
      names.add(cls.Name);
    }
    System.assert(
      names.contains('SchedulerFixtureTestOne'),
      'Selector should find fixture test class one'
    );
    System.assert(
      names.contains('SchedulerFixtureTestTwo'),
      'Selector should find fixture test class two'
    );
  }

  @isTest
  static void getTestClasses_searchNarrowsToMatchingName() {
    TestClassSelector selector = new TestClassSelector();
    List<ApexClass> results = selector.getTestClasses(
      'SchedulerFixtureTestOne'
    );

    for (ApexClass cls : results) {
      System.assert(
        cls.Name.contains('SchedulerFixtureTestOne'),
        'All results should match the search term'
      );
    }
  }

  @isTest
  static void getAllTestClasses_includesFixtures() {
    Set<String> names = new Set<String>();
    for (ApexClass cls : new TestClassSelector().getAllTestClasses()) {
      names.add(cls.Name);
    }
    System.assert(names.contains('SchedulerFixtureTestOne'));
    System.assert(names.contains('SchedulerFixtureTestTwo'));
  }

  @isTest
  static void getClassesByIds_emptySet_returnsEmptyList() {
    System.assertEquals(
      0,
      new TestClassSelector().getClassesByIds(new Set<Id>()).size()
    );
  }
}
