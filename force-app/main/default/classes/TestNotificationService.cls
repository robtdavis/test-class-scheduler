/**
 * Sends the completion notification email for a finished Test_Run__c. Recipients are validated
 * defensively again here (in addition to TestSchedulerService's save-time validation) since the
 * value read back from the record could in principle have been changed by another path.
 */
public with sharing class TestNotificationService {
  private final IEmailGateway gateway;

  public TestNotificationService() {
    this(new MessagingEmailGateway());
  }

  @TestVisible
  private TestNotificationService(IEmailGateway gateway) {
    this.gateway = gateway;
  }

  public void sendRunCompletionEmail(
    Test_Run__c run,
    String summaryText,
    String failureDetailsText
  ) {
    EmailRequest request = buildRequest(run, summaryText, failureDetailsText);
    gateway.sendEmails(new List<EmailRequest>{ request });
  }

  /** Builds the email for a single run without sending it, so callers can batch several together. */
  public EmailRequest buildRequest(
    Test_Run__c run,
    String summaryText,
    String failureDetailsText
  ) {
    List<String> recipients = parseRecipients(run.Notification_Recipients__c);
    if (recipients.isEmpty()) {
      throw new TestNotificationException(
        'No valid notification recipients are configured for this run.'
      );
    }

    Boolean success =
      run.Status__c == 'Completed' &&
      (run.Failed_Tests__c == null ||
      run.Failed_Tests__c == 0);
    String subject =
      'Apex Test Scheduler: ' +
      (success ? 'Success' : 'Failure') +
      ' (' +
      run.Status__c +
      ')';
    String body = summaryText;
    if (String.isNotBlank(failureDetailsText)) {
      body += '\n\nFailed tests:\n' + failureDetailsText;
    }
    return new EmailRequest(recipients, subject, body);
  }

  /** Sends a pre-built batch of emails (e.g. from a stale-run recovery sweep) in one call. */
  public void sendBatch(List<EmailRequest> requests) {
    if (requests == null || requests.isEmpty()) {
      return;
    }
    gateway.sendEmails(requests);
  }

  private List<String> parseRecipients(String rawRecipients) {
    List<String> valid = new List<String>();
    if (String.isBlank(rawRecipients)) {
      return valid;
    }
    for (String address : rawRecipients.split(',')) {
      String trimmed = address.trim();
      if (Pattern.matches('^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$', trimmed)) {
        valid.add(trimmed);
      }
    }
    return valid;
  }

  public class TestNotificationException extends Exception {
  }
}
