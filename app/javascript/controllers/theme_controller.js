import { Controller } from "@hotwired/stimulus"

// Cycles the server-owned theme preference without duplicating persistence.
export default class extends Controller {
  static targets = ["preference"]
  static values = { current: String }

  cycle() {
    const preferences = ["system", "light", "dark"]
    const nextIndex = (preferences.indexOf(this.currentValue) + 1) % preferences.length
    const nextPreference = preferences[nextIndex]
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
