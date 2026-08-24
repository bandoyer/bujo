import { Controller } from "@hotwired/stimulus"

// Cycles a server-owned display preference while optimistically stamping its
// HTML data attribute so neither theme nor lettering flashes before reload.
export default class extends Controller {
  static targets = ["preference"]
  static values = { choices: Array, attribute: String }

  cycle() {
    const preference = this.nextPreference()
    this.preferenceTarget.value = preference
    this.applyPreference(preference)
    this.element.requestSubmit()
  }

  nextPreference() {
    const currentIndex = this.choicesValue.indexOf(this.preferenceTarget.value)
    return this.choicesValue[(currentIndex + 1) % this.choicesValue.length]
  }

  applyPreference(preference) {
    if (preference === this.choicesValue[0]) {
      delete document.documentElement.dataset[this.attributeValue]
    } else {
      document.documentElement.dataset[this.attributeValue] = preference
    }
  }
}
