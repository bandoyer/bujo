import { Controller } from "@hotwired/stimulus"

// The order the header toggle walks; "system" means no explicit choice.
const THEME_CYCLE = ["system", "light", "dark"]

// Cycles the server-owned theme preference without duplicating persistence.
export default class extends Controller {
  static targets = ["preference"]
  static values = { current: String }

  cycle() {
    const nextIndex = (THEME_CYCLE.indexOf(this.currentValue) + 1) % THEME_CYCLE.length
    const nextPreference = THEME_CYCLE[nextIndex]
    this.preferenceTarget.value = nextPreference
    this.applyPreference(nextPreference)
    this.element.requestSubmit()
  }

  applyPreference(preference) {
    if (preference === "system") {
      delete document.documentElement.dataset.theme
    } else {
      document.documentElement.dataset.theme = preference
    }
  }
}
