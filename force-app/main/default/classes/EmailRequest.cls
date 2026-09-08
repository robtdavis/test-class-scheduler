/** Plain data holder for a single outbound notification email. */
public class EmailRequest {
  public List<String> toAddresses;
  public String subject;
  public String body;

  public EmailRequest(List<String> toAddresses, String subject, String body) {
    this.toAddresses = toAddresses;
    this.subject = subject;
    this.body = body;
  }
}
