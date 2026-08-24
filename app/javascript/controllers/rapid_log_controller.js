import { Controller } from "@hotwired/stimulus"

// Keeps rapid-log kind selection and input focus local to the capture form.
export default class extends Controller {
  static targets = ["kind", "line"]

  selectKind(event) {
    const selectedKind = event.currentTarget.dataset.kind
    this.kindTarget.value = selectedKind

    this.element.querySelectorAll("[data-kind]").forEach((button) => {
      const isSelected = button.dataset.kind === selectedKind
      button.setAttribute("aria-pressed", isSelected.toString())
      button.classList.toggle("rapid-log__kind--selected", isSelected)
    })

    this.focus()
  }

  focus() {
    this.lineTarget.focus()
  }
}
