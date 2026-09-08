/**
 * Best-effort Tooling API self-callout for org-wide code coverage, via an optional Named Credential
 * named "TestSchedulerToolingApi" that the admin configures manually (Tooling API access requires
 * OAuth against this same org; it cannot be provisioned automatically as part of a metadata deploy,
 * and per project rules this must never be done with a raw session-ID callout hack). If the Named
 * Credential isn't configured, or the callout fails for any reason, this returns null rather than
 * guessing - callers must treat null as "coverage unavailable", not zero.
 */
public with sharing class ToolingApiCoverageGateway implements IToolingCoverageGateway {
  @TestVisible
  private static final String NAMED_CREDENTIAL = 'callout:TestSchedulerToolingApi';

  public Decimal getOrgWideCoveragePercent() {
    try {
      HttpRequest request = new HttpRequest();
      request.setEndpoint(
        NAMED_CREDENTIAL +
        '/services/data/v67.0/tooling/query?q=SELECT+PercentCovered+FROM+ApexOrgWideCoverage'
      );
      request.setMethod('GET');
      request.setTimeout(10000);
      HttpResponse response = new Http().send(request);
      if (response.getStatusCode() != 200) {
        return null;
      }
      Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(
        response.getBody()
      );
      List<Object> records = (List<Object>) parsed.get('records');
      if (records == null || records.isEmpty()) {
        return null;
      }
      Object percent = ((Map<String, Object>) records[0]).get('PercentCovered');
      return percent == null ? null : (Decimal) percent;
    } catch (Exception ex) {
      // No Named Credential configured, callout disabled, or an unexpected response shape -
      // all treated the same way: coverage is simply not available for this run.
      return null;
    }
  }
}
