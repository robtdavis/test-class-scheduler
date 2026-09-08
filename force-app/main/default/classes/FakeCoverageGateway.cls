/** Test double for IToolingCoverageGateway; defaults to "unavailable" (null) like an unconfigured org. */
@isTest
public class FakeCoverageGateway implements IToolingCoverageGateway {
  public Decimal percentToReturn;

  public Decimal getOrgWideCoveragePercent() {
    return percentToReturn;
  }
}
