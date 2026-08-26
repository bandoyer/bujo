import { Controller } from "@hotwired/stimulus"

// Owns the transient writing controls shared by Daily and Future Logs. The
// forms remain ordinary server requests; only reveal, composition, and focus
// are local so navigating away always returns to a closed notebook page.
export default class extends Controller {
  static targets = ["toggle", "panel", "focus", "day", "on"]

  // Future months have two buttons for one panel. Remember the control that
  // opened it so success can restore that one, not the first matching toggle.
  activeToggle = null

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

    const toggle = this.activeToggle
    event.currentTarget.reset()
    this.panelFor(toggle).closest(".future-log__month")?.classList.remove("future-log__month--empty")
    this.closeAll()
    toggle.focus()
  }

  closeAll() {
    this.toggleTargets.forEach((toggle) => this.setExpanded(toggle, false))
    this.activeToggle = null
  }

  open(toggle) {
    this.activeToggle = toggle
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

  // One controller serves every reveal on the page, so its target lists span
  // all of them. Anything scoped to a single form or panel is found within it.
  targetWithin(root, name) {
    return root.querySelector(`[data-placement-target~='${name}']`)
  }
}
