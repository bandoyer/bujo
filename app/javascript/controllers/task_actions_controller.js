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
    if (shouldOpen) this.setExpanded(toggle, true)
  }

  showSchedule(event) {
    this.showStep(this.stripFor(event.currentTarget), "schedule")
  }

  showMove(event) {
    this.showStep(this.stripFor(event.currentTarget), "move")
  }

  // Every step rewinds to the same place, so one handler serves them all.
  cancelStep(event) {
    this.showStep(this.stripFor(event.currentTarget), "actions")
  }

  // One row is open at a time, and a strip always reopens on its actions -
  // so closing rewinds the step rather than leaving it in the date step.
  closeAll() {
    this.toggleTargets.forEach((toggle) => this.setExpanded(toggle, false))
    this.stripTargets.forEach((strip) => this.showStep(strip, "actions"))
  }

  // One place knows what revealed means: the control, its row, and its strip.
  setExpanded(toggle, expanded) {
    toggle.setAttribute("aria-expanded", String(expanded))
    toggle.closest(".entry").classList.toggle("entry--selected", expanded)
    document.getElementById(toggle.getAttribute("aria-controls")).hidden = !expanded
  }

  // Exactly one step of a strip shows at a time. A done or struck row has no
  // date step, and needs no special case: it simply has one fewer to hide.
  showStep(strip, step) {
    strip.querySelectorAll("[data-step]").forEach((element) => {
      element.hidden = element.dataset.step !== step
    })
  }

  stripFor(control) {
    return control.closest(".entry__action-strip")
  }
}
