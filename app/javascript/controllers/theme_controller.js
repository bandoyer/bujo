import { Controller } from "@hotwired/stimulus"

// The order the header toggle walks; "system" means no explicit choice.
const THEME_CYCLE = ["system", "light", "dark"]

// Cycles the server-owned theme preference without duplicating persistence.
// The submitted field is the single source of truth for the current choice,
// so the cycle reads it rather than a second copy stamped on the form.
export default class extends Controller {
  static targets = ["preference"]

  cycle() {
    this.preferenceTarget.value = this.nextPreference()
    this.applyPreference(this.preferenceTarget.value)
    this.element.requestSubmit()
  }

  nextPreference() {
    const nextIndex = (THEME_CYCLE.indexOf(this.preferenceTarget.value) + 1) % THEME_CYCLE.length
    return THEME_CYCLE[nextIndex]
  }

  applyPreference(preference) {
    if (preference === "system") {
      delete document.documentElement.dataset.theme
    } else {
      document.documentElement.dataset.theme = preference
    }
  }
}
