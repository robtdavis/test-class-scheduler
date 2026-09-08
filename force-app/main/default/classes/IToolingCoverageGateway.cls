/**
 * Narrow seam for retrieving org-wide Apex code coverage. Real code coverage aggregates
 * (ApexCodeCoverageAggregate/ApexOrgWideCoverage) are Tooling-API-only objects - they cannot be
 * queried from plain Apex SOQL (confirmed: referencing them in Apex fails to compile with
 * "Invalid type"). Getting a real percentage therefore requires a Tooling API callout, which needs
 * a Named Credential the admin must configure manually (see README) - this is not something we can
 * fabricate or guarantee is set up, so the return value is nullable and callers must treat null as
 * "unavailable", never substituting a fake number.
 */
public interface IToolingCoverageGateway {
  Decimal getOrgWideCoveragePercent();
}
