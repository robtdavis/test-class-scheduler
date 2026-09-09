import { createElement } from "lwc";
import ApexTestScheduler from "c/apexTestScheduler";
import getScheduleConfiguration from "@salesforce/apex/TestSchedulerController.getScheduleConfiguration";
import getTestClassOptions from "@salesforce/apex/TestSchedulerController.getTestClassOptions";
import saveSchedule from "@salesforce/apex/TestSchedulerController.saveSchedule";
import getRecentRuns from "@salesforce/apex/TestSchedulerController.getRecentRuns";

jest.mock(
  "@salesforce/apex/TestSchedulerController.getScheduleConfiguration",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/TestSchedulerController.getTestClassOptions",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/TestSchedulerController.saveSchedule",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/TestSchedulerController.deactivateSchedule",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/TestSchedulerController.deleteSchedule",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/TestSchedulerController.runNow",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/TestSchedulerController.getRecentRuns",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

function flushPromises() {
  return Promise.resolve()
    .then(() => Promise.resolve())
    .then(() => Promise.resolve());
}

describe("c-apex-test-scheduler", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("shows a spinner while loading", () => {
    getScheduleConfiguration.mockResolvedValue(null);
    getTestClassOptions.mockResolvedValue([]);

    const element = createElement("c-apex-test-scheduler", {
      is: ApexTestScheduler
    });
    document.body.appendChild(element);

    const spinner = element.shadowRoot.querySelector("lightning-spinner");
    expect(spinner).not.toBeNull();
  });

  it("shows an empty schedule state when no schedule exists", async () => {
    getScheduleConfiguration.mockResolvedValue(null);
    getTestClassOptions.mockResolvedValue([]);

    const element = createElement("c-apex-test-scheduler", {
      is: ApexTestScheduler
    });
    document.body.appendChild(element);
    await flushPromises();

    const text = element.shadowRoot.textContent;
    expect(text).toContain("No schedule has been saved yet.");
    expect(text).toContain("No test runs yet.");
    expect(text).toContain("No execution history yet.");
  });

  it("renders saved schedule details and recent runs", async () => {
    getScheduleConfiguration.mockResolvedValue({
      scheduleId: "a01000000000001AAA",
      active: true,
      runAllTests: true,
      runTimeHour: 9,
      runTimeMinute: 30,
      timeZone: "America/New_York",
      monday: true,
      notificationRecipients: "admin@example.com",
      cronExpression: "0 30 9 ? * MON",
      selectedClassIds: []
    });
    getTestClassOptions.mockResolvedValue([]);
    getRecentRuns.mockResolvedValue([
      {
        runId: "a02000000000001AAA",
        status: "Completed",
        startedDate: "2026-01-01T09:30:00.000Z",
        totalTests: 10,
        passedTests: 10,
        failedTests: 0
      }
    ]);

    const element = createElement("c-apex-test-scheduler", {
      is: ApexTestScheduler
    });
    document.body.appendChild(element);
    await flushPromises();

    const text = element.shadowRoot.textContent;
    expect(text).toContain("0 30 9 ? * MON");
    expect(text).toContain("Completed");
  });

  it("saves the schedule when the save button is clicked", async () => {
    getScheduleConfiguration.mockResolvedValue(null);
    getTestClassOptions.mockResolvedValue([]);
    saveSchedule.mockResolvedValue({
      scheduleId: "a01000000000002AAA",
      active: true,
      runAllTests: true,
      runTimeHour: 8,
      runTimeMinute: 0,
      selectedClassIds: []
    });
    getRecentRuns.mockResolvedValue([]);

    const element = createElement("c-apex-test-scheduler", {
      is: ApexTestScheduler
    });
    document.body.appendChild(element);
    await flushPromises();

    const saveButton = Array.from(
      element.shadowRoot.querySelectorAll("lightning-button")
    ).find((btn) => btn.label === "Save Schedule");
    expect(saveButton).not.toBeNull();
    saveButton.click();
    await flushPromises();

    expect(saveSchedule).toHaveBeenCalled();
  });

  it.each(["admin@example.com", "admin@example.com, second@example.com", ""])(
    "sends the current textarea recipients when saving: %s",
    async (recipients) => {
      getScheduleConfiguration.mockResolvedValue(null);
      getTestClassOptions.mockResolvedValue([]);
      saveSchedule.mockResolvedValue(null);
      const element = createElement("c-apex-test-scheduler", {
        is: ApexTestScheduler
      });
      document.body.appendChild(element);
      await flushPromises();

      const textarea = element.shadowRoot.querySelector("lightning-textarea");
      textarea.dispatchEvent(
        new CustomEvent("change", { detail: { value: "old@example.com" } })
      );
      await flushPromises();
      textarea.dispatchEvent(
        new CustomEvent("change", { detail: { value: recipients } })
      );
      const saveButton = Array.from(
        element.shadowRoot.querySelectorAll("lightning-button")
      ).find((button) => button.label === "Save Schedule");
      saveButton.click();
      await flushPromises();

      expect(saveSchedule).toHaveBeenCalledWith({
        scheduleInput: expect.objectContaining({
          notificationRecipients: recipients
        })
      });
    }
  );

  it("surfaces an apex error message", async () => {
    getScheduleConfiguration.mockRejectedValue({ body: { message: "Boom" } });
    getTestClassOptions.mockResolvedValue([]);

    const element = createElement("c-apex-test-scheduler", {
      is: ApexTestScheduler
    });
    document.body.appendChild(element);
    await flushPromises();

    expect(element.shadowRoot.textContent).toContain("Boom");
  });
});
