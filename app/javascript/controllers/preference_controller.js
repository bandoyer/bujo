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

  // The default leads the cycle and is stored as the absence of a cookie, so
  // the server stamps no attribute for it and neither does the optimistic pass.
  get defaultChoice() {
    return this.choicesValue[0]
  }

  applyPreference(preference) {
    if (preference === this.defaultChoice) {
      delete document.documentElement.dataset[this.attributeValue]
    } else {
      document.documentElement.dataset[this.attributeValue] = preference
    }
  }
}
