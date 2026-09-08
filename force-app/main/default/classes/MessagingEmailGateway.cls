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
    Messaging.sendEmail(emails);
  }
}
