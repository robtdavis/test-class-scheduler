/**
 * Lightweight DTO for an available Apex test class option shown in the LWC selector.
 */
public class TestClassOptionDTO {
  @AuraEnabled
  public Id classId;
  @AuraEnabled
  public String className;

  public TestClassOptionDTO(Id classId, String className) {
    this.classId = classId;
    this.className = className;
  }
}
