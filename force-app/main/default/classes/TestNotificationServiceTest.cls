@isTest
private class TestNotificationServiceTest {
  @isTest
  static void sendRunCompletionEmail_validRecipients_sendsOneBatchedEmail() {
    FakeEmailGateway gateway = new FakeEmailGateway();
    Test_Run__c run = new Test_Run__c(
      Status__c = 'Completed',
      Failed_Tests__c = 0,
      Notification_Recipients__c = 'a@example.com, b@example.com'
    );

    new TestNotificationService(gateway)
      .sendRunCompletionEmail(run, 'summary text', '');

    System.assertEquals(1, gateway.invocationCount);
    System.assertEquals(1, gateway.lastRequests.size());
    System.assertEquals(2, gateway.lastRequests[0].toAddresses.size());
    System.assert(gateway.lastRequests[0].subject.contains('Success'));
    System.assert(gateway.lastRequests[0].body.contains('summary text'));
  }

  @isTest
  static void sendRunCompletionEmail_failedRun_subjectMentionsFailureAndIncludesFailureDetails() {
    FakeEmailGateway gateway = new FakeEmailGateway();
    Test_Run__c run = new Test_Run__c(
      Status__c = 'Completed',
      Failed_Tests__c = 1,
      Notification_Recipients__c = 'a@example.com'
    );

    new TestNotificationService(gateway)
      .sendRunCompletionEmail(run, 'summary text', 'SomeClass.testFoo: boom');

    System.assert(gateway.lastRequests[0].subject.contains('Failure'));
    System.assert(
      gateway.lastRequests[0].body.contains('SomeClass.testFoo: boom')
    );
  }

  @isTest
  static void sendRunCompletionEmail_missingRecipients_throws() {
    FakeEmailGateway gateway = new FakeEmailGateway();
    Test_Run__c run = new Test_Run__c(
      Status__c = 'Completed',
      Notification_Recipients__c = null
    );

    try {
      new TestNotificationService(gateway)
        .sendRunCompletionEmail(run, 'summary text', '');
      System.assert(false, 'Expected an exception for missing recipients');
    } catch (TestNotificationService.TestNotificationException ex) {
      System.assert(
        ex.getMessage().contains('No valid notification recipients')
      );
    }
    System.assertEquals(0, gateway.invocationCount);
  }

  @isTest
  static void sendRunCompletionEmail_invalidRecipients_areFilteredOutAndThrowsIfNoneRemain() {
    FakeEmailGateway gateway = new FakeEmailGateway();
    Test_Run__c run = new Test_Run__c(
      Status__c = 'Completed',
      Notification_Recipients__c = 'not-an-email, also bad'
    );

    try {
      new TestNotificationService(gateway)
        .sendRunCompletionEmail(run, 'summary text', '');
      System.assert(
        false,
        'Expected an exception when no recipients are valid'
      );
    } catch (TestNotificationService.TestNotificationException ex) {
      System.assert(
        ex.getMessage().contains('No valid notification recipients')
      );
    }
  }

  @isTest
  static void sendRunCompletionEmail_someInvalidRecipients_onlyValidOnesUsed() {
    FakeEmailGateway gateway = new FakeEmailGateway();
    Test_Run__c run = new Test_Run__c(
      Status__c = 'Completed',
      Failed_Tests__c = 0,
      Notification_Recipients__c = 'good@example.com, not-an-email'
    );

    new TestNotificationService(gateway)
      .sendRunCompletionEmail(run, 'summary text', '');

    System.assertEquals(1, gateway.lastRequests[0].toAddresses.size());
    System.assertEquals(
      'good@example.com',
      gateway.lastRequests[0].toAddresses[0]
    );
  }

  @isTest
  static void sendBatch_multipleRequests_sentInOneGatewayInvocation() {
    FakeEmailGateway gateway = new FakeEmailGateway();
    TestNotificationService service = new TestNotificationService(gateway);
    List<EmailRequest> requests = new List<EmailRequest>();
    for (Integer i = 0; i < 25; i++) {
      requests.add(
        new EmailRequest(
          new List<String>{ 'user' + i + '@example.com' },
          'Subject ' + i,
          'Body ' + i
        )
      );
    }

    service.sendBatch(requests);

    System.assertEquals(
      1,
      gateway.invocationCount,
      'All 25 emails should be sent via a single gateway invocation'
    );
    System.assertEquals(25, gateway.lastRequests.size());
  }

  @isTest
  static void sendBatch_emptyList_doesNotInvokeGateway() {
    FakeEmailGateway gateway = new FakeEmailGateway();
    new TestNotificationService(gateway).sendBatch(new List<EmailRequest>());
    System.assertEquals(0, gateway.invocationCount);
  }

  @isTest
  static void sendRunCompletionEmail_gatewayThrows_propagatesToCaller() {
    FakeEmailGateway gateway = new FakeEmailGateway();
    gateway.throwOnSend = true;
    Test_Run__c run = new Test_Run__c(
      Status__c = 'Completed',
      Notification_Recipients__c = 'a@example.com'
    );

    try {
      new TestNotificationService(gateway)
        .sendRunCompletionEmail(run, 'summary text', '');
      System.assert(
        false,
        'Expected the simulated gateway failure to propagate'
      );
    } catch (TestNotificationService.TestNotificationException ex) {
      System.assert(ex.getMessage().contains('Simulated'));
    }
  }
}
