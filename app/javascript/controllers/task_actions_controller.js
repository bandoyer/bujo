import { Controller } from "@hotwired/stimulus"

// Owns the Daily Log's transient action reveal state. Lifecycle forms remain
// ordinary server requests; this controller only chooses which hidden strip
// content the reader can see during the current gesture.
export default class extends Controller {
  static targets = ["toggle", "strip"]

  connect() {
    const focused = this.element.querySelector("[autofocus]")
    if (!focused) return

    // Let native autofocus and font layout settle, then correct only clipped
    // edges. Deep wrapped trees can otherwise leave the focus cue just
    // above the phone viewport after a full-page command response.
    this.revealFocus(focused)
    requestAnimationFrame(() => this.revealFocus(focused))
  }

  toggle(event) {
    const toggle = event.currentTarget
    const shouldOpen = toggle.getAttribute("aria-expanded") === "false"

    this.closeAll()
    if (shouldOpen) this.setExpanded(toggle, true)
  }

  showSchedule(event) {
    this.showStep(this.stripFor(event.currentTarget), "schedule")
  }

  showEdit(event) {
    const strip = this.stripFor(event.currentTarget)
    this.showStep(strip, "edit")
    strip.querySelector("[data-step='edit'] [data-rapid-log-target='line']")?.focus()
  }

  showMove(event) {
    this.showStep(this.stripFor(event.currentTarget), "move")
  }

  showChild(event) {
    const strip = this.stripFor(event.currentTarget)
    this.showStep(strip, "child")
    strip.querySelector("[data-step='child'] [data-rapid-log-target='line']")?.focus()
  }

  // Every step rewinds to the same place, so one handler serves them all.
  cancelStep(event) {
    const strip = this.stripFor(event.currentTarget)
    this.showStep(strip, "actions")
    strip.closest(".entry").querySelector(".entry__toggle")?.focus()
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

  revealFocus(focused) {
    const rectangle = focused.getBoundingClientRect()
    const clearance = 5
    const verticalCorrection = Math.min(0, rectangle.top - clearance)
    window.scrollBy({ left: -window.scrollX, top: verticalCorrection })
  }
}
