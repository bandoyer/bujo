import { Controller } from "@hotwired/stimulus"

// Owns the transient writing controls shared by Daily and Future Logs. The
// forms remain ordinary server requests; only reveal, composition, and focus
// are local so navigating away always returns to a closed notebook page.
export default class extends Controller {
  static targets = ["toggle", "panel", "focus", "day", "on"]

  toggle(event) {
    const toggle = event.currentTarget
    const shouldOpen = toggle.getAttribute("aria-expanded") === "false"

    this.closeAll()
    if (shouldOpen) this.open(toggle)
  }

  composeDate(event) {
    const form = event.currentTarget
    const month = form.dataset.month
    const day = this.targetWithin(form, "day").value.padStart(2, "0")

    this.targetWithin(form, "on").value = `${month}-${day}`
  }

  submitted(event) {
    if (!event.detail.success) return

    const panel = event.currentTarget.closest("[data-placement-target~='panel']")
    const toggle = this.toggleFor(panel)
    event.currentTarget.reset()
    panel.closest(".future-log__month")?.classList.remove("future-log__month--empty")
    this.setExpanded(toggle, false)
    toggle.focus()
  }

  closeAll() {
    this.toggleTargets.forEach((toggle) => this.setExpanded(toggle, false))
  }

  open(toggle) {
    this.setExpanded(toggle, true)
    this.targetWithin(this.panelFor(toggle), "focus")?.focus()
  }

  setExpanded(toggle, expanded) {
    toggle.setAttribute("aria-expanded", String(expanded))
    this.panelFor(toggle).hidden = !expanded
  }

  panelFor(toggle) {
    return document.getElementById(toggle.getAttribute("aria-controls"))
  }

  toggleFor(panel) {
    return this.toggleTargets.find((toggle) => toggle.getAttribute("aria-controls") === panel.id)
  }

  // One controller serves every reveal on the page, so its target lists span
  // all of them. Anything scoped to a single form or panel is found within it.
  targetWithin(root, name) {
    return root.querySelector(`[data-placement-target~='${name}']`)
  }
}
