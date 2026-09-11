/** Real Messaging.sendEmail-backed implementation of IEmailGateway. */
public class MessagingEmailGateway implements IEmailGateway {
  public void sendEmails(List<EmailRequest> requests) {
    if (requests == null || requests.isEmpty()) {
      return;
    }
    List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
    for (EmailRequest request : requests) {
      Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
      email.setToAddresses(request.toAddresses);
      email.setSubject(request.subject);
      email.setPlainTextBody(request.body);
      email.setSaveAsActivity(false);
      emails.add(email);
    }
    // Atomic batch: a rejected message must not be recorded as accepted.
    verifyResults(Messaging.sendEmail(emails, true), emails.size());
  }

  @TestVisible
  private static void verifyResults(
    List<Messaging.SendEmailResult> results,
    Integer expectedCount
  ) {
    if (results == null || results.size() != expectedCount) {
      throw new TestNotificationService.TestNotificationException(
        'Salesforce returned an incomplete email send result.'
      );
    }
    List<String> errors = new List<String>();
    for (Messaging.SendEmailResult result : results) {
      if (!result.isSuccess()) {
        for (Messaging.SendEmailError error : result.getErrors()) {
          errors.add(
            String.valueOf(error.getStatusCode()) + ': ' + error.getMessage()
          );
        }
        if (result.getErrors().isEmpty())
          errors.add('Salesforce rejected the email without an error message.');
      }
    }
    if (!errors.isEmpty()) {
      throw new TestNotificationService.TestNotificationException(
        String.join(errors, '; ')
      );
    }
  }
}
