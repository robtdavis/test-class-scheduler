@isTest
private class MessagingEmailGatewayTest {
  @isTest
  static void rejectedResult_preservesPlatformError() {
    Messaging.SingleEmailMessage invalidEmail = new Messaging.SingleEmailMessage();
    invalidEmail.setToAddresses(new List<String>{ 'not-an-email' });
    invalidEmail.setSubject('Validation test');
    invalidEmail.setPlainTextBody('Validation test');
    List<Messaging.SendEmailResult> results = Messaging.sendEmail(
      new List<Messaging.SingleEmailMessage>{ invalidEmail },
      false
    );
    System.assertEquals(false, results[0].isSuccess());
    try {
      MessagingEmailGateway.verifyResults(results, 1);
      System.assert(false, 'Expected rejection');
    } catch (TestNotificationService.TestNotificationException ex) {
      System.assert(
        ex.getMessage()
          .contains(String.valueOf(results[0].getErrors()[0].getStatusCode()))
      );
      System.assert(
        ex.getMessage().contains(results[0].getErrors()[0].getMessage())
      );
    }
  }
  @isTest
  static void successfulResult_isAccepted() {
    List<Messaging.SendEmailResult> results = (List<Messaging.SendEmailResult>) JSON.deserialize(
      '[{"success":true,"errors":[]}]',
      List<Messaging.SendEmailResult>.class
    );
    MessagingEmailGateway.verifyResults(results, 1);
  }
  @isTest
  static void missingResult_isNotAccepted() {
    try {
      MessagingEmailGateway.verifyResults(
        new List<Messaging.SendEmailResult>(),
        1
      );
      System.assert(false, 'Expected incomplete result rejection');
    } catch (TestNotificationService.TestNotificationException ex) {
      System.assert(ex.getMessage().contains('incomplete'));
    }
  }
}
