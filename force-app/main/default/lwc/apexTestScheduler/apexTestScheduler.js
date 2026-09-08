import { LightningElement } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getScheduleConfiguration from "@salesforce/apex/TestSchedulerController.getScheduleConfiguration";
import getTestClassOptions from "@salesforce/apex/TestSchedulerController.getTestClassOptions";
import saveSchedule from "@salesforce/apex/TestSchedulerController.saveSchedule";
import deactivateSchedule from "@salesforce/apex/TestSchedulerController.deactivateSchedule";
import deleteSchedule from "@salesforce/apex/TestSchedulerController.deleteSchedule";
import runNow from "@salesforce/apex/TestSchedulerController.runNow";
import getRecentRuns from "@salesforce/apex/TestSchedulerController.getRecentRuns";

const WEEKDAYS = [
  { key: "sunday", label: "Sun" },
  { key: "monday", label: "Mon" },
  { key: "tuesday", label: "Tue" },
  { key: "wednesday", label: "Wed" },
  { key: "thursday", label: "Thu" },
  { key: "friday", label: "Fri" },
  { key: "saturday", label: "Sat" }
];

export default class ApexTestScheduler extends LightningElement {
  isLoading = true;
  isSaving = false;
  errorMessage;
  successMessage;

  scheduleId;
  active = false;
  runAllTests = true;
  runTimeValue = "08:00";
  timeZone;
  notificationRecipients = "";
  cronExpression;
  weekdayState = {
    sunday: false,
    monday: false,
    tuesday: false,
    wednesday: false,
    thursday: false,
    friday: false,
    saturday: false
  };

  searchTerm = "";
  classOptions = [];
  selectedClassIds = [];

  recentRuns = [];

  get weekdayItems() {
    return WEEKDAYS.map((day) => ({
      key: day.key,
      label: day.label,
      checked: !!this.weekdayState[day.key]
    }));
  }

  get classOptionItems() {
    const selected = new Set(this.selectedClassIds);
    return this.classOptions.map((option) => ({
      classId: option.classId,
      className: option.className,
      checked: selected.has(option.classId)
    }));
  }

  get hasSchedule() {
    return !!this.scheduleId;
  }

  get selectionDisabled() {
    return this.runAllTests;
  }

  get saveButtonLabel() {
    return this.hasSchedule ? "Update Schedule" : "Save Schedule";
  }

  get timeZoneDisplay() {
    // System.schedule() runs in the time zone of the saving user - it cannot be set to an
    // arbitrary value, so this is only ever shown after a save, never editable.
    return (
      this.timeZone ||
      "Set automatically to your time zone when the schedule is saved and active."
    );
  }

  get latestRun() {
    return this.recentRuns.length ? this.recentRuns[0] : null;
  }

  get hasRecentRuns() {
    return this.recentRuns.length > 0;
  }

  get runNowDisabled() {
    return this.isSaving || !this.hasSchedule;
  }

  connectedCallback() {
    this.loadAll();
  }

  async loadAll() {
    this.isLoading = true;
    this.errorMessage = undefined;
    try {
      const [config, options] = await Promise.all([
        getScheduleConfiguration(),
        getTestClassOptions({ searchTerm: "" })
      ]);
      this.applyConfig(config);
      this.classOptions = options;
      if (this.scheduleId) {
        this.recentRuns = await getRecentRuns({
          scheduleId: this.scheduleId,
          maxResults: 5
        });
      }
    } catch (error) {
      this.setError(error);
    } finally {
      this.isLoading = false;
    }
  }

  applyConfig(config) {
    if (!config) {
      return;
    }
    this.scheduleId = config.scheduleId;
    this.active = !!config.active;
    this.runAllTests = !!config.runAllTests;
    this.runTimeValue = this.toTimeInputValue(
      config.runTimeHour,
      config.runTimeMinute
    );
    this.timeZone = config.timeZone;
    this.notificationRecipients = config.notificationRecipients || "";
    this.cronExpression = config.cronExpression;
    this.selectedClassIds = config.selectedClassIds || [];
    this.weekdayState = {
      sunday: !!config.sunday,
      monday: !!config.monday,
      tuesday: !!config.tuesday,
      wednesday: !!config.wednesday,
      thursday: !!config.thursday,
      friday: !!config.friday,
      saturday: !!config.saturday
    };
  }

  toTimeInputValue(hour, minute) {
    const h = Number.isInteger(hour) ? hour : 8;
    const m = Number.isInteger(minute) ? minute : 0;
    return `${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")}`;
  }

  parseTimeInputValue(value) {
    const [hourText, minuteText] = (value || "08:00").split(":");
    return { hour: parseInt(hourText, 10), minute: parseInt(minuteText, 10) };
  }

  handleActiveChange(event) {
    this.active = event.target.checked;
  }

  handleRunAllChange(event) {
    this.runAllTests = event.target.checked;
  }

  handleTimeChange(event) {
    this.runTimeValue = event.target.value;
  }

  handleRecipientsChange(event) {
    this.notificationRecipients = event.target.value;
  }

  handleDayToggle(event) {
    const day = event.target.dataset.day;
    this.weekdayState = { ...this.weekdayState, [day]: event.target.checked };
  }

  handleClassToggle(event) {
    const classId = event.target.dataset.classId;
    const isChecked = event.target.checked;
    const current = new Set(this.selectedClassIds);
    if (isChecked) {
      current.add(classId);
    } else {
      current.delete(classId);
    }
    this.selectedClassIds = Array.from(current);
  }

  async handleSearchChange(event) {
    this.searchTerm = event.target.value;
    try {
      this.classOptions = await getTestClassOptions({
        searchTerm: this.searchTerm
      });
    } catch (error) {
      this.setError(error);
    }
  }

  async handleSave() {
    this.isSaving = true;
    this.errorMessage = undefined;
    this.successMessage = undefined;
    try {
      const { hour, minute } = this.parseTimeInputValue(this.runTimeValue);
      const input = {
        scheduleId: this.scheduleId,
        active: this.active,
        runAllTests: this.runAllTests,
        runTimeHour: hour,
        runTimeMinute: minute,
        notificationRecipients: this.notificationRecipients,
        selectedClassIds: this.selectionDisabled ? [] : this.selectedClassIds,
        ...this.weekdayState
      };
      const saved = await saveSchedule(input);
      this.applyConfig(saved);
      this.recentRuns = this.scheduleId
        ? await getRecentRuns({ scheduleId: this.scheduleId, maxResults: 5 })
        : [];
      this.successMessage = "Schedule saved.";
      this.notify("Success", this.successMessage, "success");
    } catch (error) {
      this.setError(error);
    } finally {
      this.isSaving = false;
    }
  }

  async handleRunNow() {
    this.isSaving = true;
    this.errorMessage = undefined;
    this.successMessage = undefined;
    try {
      await runNow({ scheduleId: this.scheduleId });
      this.recentRuns = await getRecentRuns({
        scheduleId: this.scheduleId,
        maxResults: 5
      });
      this.successMessage = "Test run started.";
      this.notify("Success", this.successMessage, "success");
    } catch (error) {
      this.setError(error);
    } finally {
      this.isSaving = false;
    }
  }

  async handleDeactivate() {
    this.isSaving = true;
    this.errorMessage = undefined;
    try {
      await deactivateSchedule({ scheduleId: this.scheduleId });
      await this.loadAll();
      this.notify("Success", "Schedule deactivated.", "success");
    } catch (error) {
      this.setError(error);
    } finally {
      this.isSaving = false;
    }
  }

  async handleDelete() {
    this.isSaving = true;
    this.errorMessage = undefined;
    try {
      await deleteSchedule({ scheduleId: this.scheduleId });
      this.scheduleId = undefined;
      this.active = false;
      this.cronExpression = undefined;
      this.timeZone = undefined;
      this.selectedClassIds = [];
      this.recentRuns = [];
      this.notify("Success", "Schedule deleted.", "success");
    } catch (error) {
      this.setError(error);
    } finally {
      this.isSaving = false;
    }
  }

  setError(error) {
    this.errorMessage =
      (error && error.body && error.body.message) ||
      (error && error.message) ||
      "An unexpected error occurred.";
    this.notify("Error", this.errorMessage, "error");
  }

  notify(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
