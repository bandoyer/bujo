import { Controller } from "@hotwired/stimulus"

// Owns the Daily Log's transient action reveal state. Lifecycle forms remain
// ordinary server requests; this controller only chooses which hidden strip
// content the reader can see during the current gesture.
export default class extends Controller {
  static targets = ["toggle", "strip"]

  toggle(event) {
    const toggle = event.currentTarget
    const shouldOpen = toggle.getAttribute("aria-expanded") === "false"

    this.closeAll()
    if (shouldOpen) this.open(toggle)
  }

  showSchedule(event) {
    this.showStep(event.currentTarget, "scheduleStep")
  }

  cancelSchedule(event) {
    this.showStep(event.currentTarget, "actionsStep")
  }

  open(toggle) {
    const strip = document.getElementById(toggle.getAttribute("aria-controls"))

    toggle.setAttribute("aria-expanded", "true")
    strip.hidden = false
    toggle.closest(".entry").classList.add("entry--selected")
  }

  closeAll() {
    this.toggleTargets.forEach((toggle) => {
      toggle.setAttribute("aria-expanded", "false")
      toggle.closest(".entry").classList.remove("entry--selected")
    })

    this.stripTargets.forEach((strip) => {
      strip.hidden = true
      this.resetToActions(strip)
    })
  }

  showStep(control, targetName) {
    const strip = control.closest(".entry__action-strip")

    strip.querySelector("[data-task-actions-target='actionsStep']").hidden = targetName !== "actionsStep"
    strip.querySelector("[data-task-actions-target='scheduleStep']").hidden = targetName !== "scheduleStep"
  }

  resetToActions(strip) {
    const actions = strip.querySelector("[data-task-actions-target='actionsStep']")
    const schedule = strip.querySelector("[data-task-actions-target='scheduleStep']")

    actions.hidden = false
    if (schedule) schedule.hidden = true
  }
}
