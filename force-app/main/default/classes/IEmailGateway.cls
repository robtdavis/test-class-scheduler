/**
 * Narrow seam around Messaging.sendEmail, so TestNotificationService's recipient/content logic can
 * be unit tested without actually sending email. Batched (one call per group of runs) so bulk
 * notification (e.g. from a stale-run recovery sweep) uses a single Messaging.sendEmail invocation
 * regardless of how many runs are being notified about.
 */
public interface IEmailGateway {
  void sendEmails(List<EmailRequest> requests);
}
