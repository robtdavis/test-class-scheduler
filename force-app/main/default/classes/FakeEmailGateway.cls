/** Test double for IEmailGateway that records the last batch instead of sending it. */
@isTest
public class FakeEmailGateway implements IEmailGateway {
  public Integer invocationCount = 0;
  public List<EmailRequest> lastRequests;
  public Boolean throwOnSend = false;

  public void sendEmails(List<EmailRequest> requests) {
    if (throwOnSend) {
      throw new EmailSendException('Simulated email send failure.');
    }
    invocationCount++;
    lastRequests = requests;
  }

  public class EmailSendException extends Exception {
  }
}
