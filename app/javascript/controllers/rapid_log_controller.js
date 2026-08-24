import { Controller } from "@hotwired/stimulus"

// Keeps rapid-log kind selection and input focus local to the capture form.
export default class extends Controller {
  static targets = ["kind", "kindButton", "line"]

  selectKind(event) {
    this.kindTarget.value = event.currentTarget.dataset.kind
    this.highlightSelectedKind()
    this.focus()
  }

  highlightSelectedKind() {
    this.kindButtonTargets.forEach((button) => {
      const isSelected = button.dataset.kind === this.kindTarget.value
      button.setAttribute("aria-pressed", isSelected.toString())
      button.classList.toggle("rapid-log__kind--selected", isSelected)
    })
  }

  focus() {
    this.lineTarget.focus()
  }
}
