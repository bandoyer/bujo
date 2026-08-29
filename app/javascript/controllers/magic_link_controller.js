import { Controller } from "@hotwired/stimulus"

// Stages a fragment bearer locally and removes it before explicit redemption.
export default class extends Controller {
  static targets = ["token", "button"]

  connect() {
    this.clear = this.clear.bind(this)
    document.addEventListener("turbo:before-cache", this.clear)
    this.clear()

    const encodedToken = window.location.hash.slice(1)
    window.history.replaceState(window.history.state, "", window.location.pathname + window.location.search)
    if (!encodedToken) return

    const token = this.decode(encodedToken)
    if (!token?.trim()) return

    this.tokenTarget.value = token
    this.buttonTarget.disabled = false
  }

  disconnect() {
    document.removeEventListener("turbo:before-cache", this.clear)
    this.clear()
  }

  clear() {
    this.tokenTarget.value = ""
    this.buttonTarget.disabled = true
  }

  decode(encodedToken) {
    try {
      return decodeURIComponent(encodedToken)
    } catch (_error) {
      return null
    }
  }
}
