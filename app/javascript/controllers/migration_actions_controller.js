import { Controller } from "@hotwired/stimulus"

// Owns only the transient destination form revealed for one outgoing task.
// Every authorization decision remains a server-side ritual command.
export default class extends Controller {
  static targets = ["choices", "collectionToggle", "futureToggle", "collectionStep", "futureStep"]

  showCollection() {
    this.show(this.collectionStepTarget, this.collectionToggleTarget)
  }

  showFuture() {
    this.show(this.futureStepTarget, this.futureToggleTarget)
  }

  cancel() {
    this.choiceButtons().forEach((choice) => { choice.hidden = false })
    this.hideSteps()
  }

  show(step, toggle) {
    this.hideSteps()
    this.choiceButtons().forEach((choice) => {
      choice.hidden = choice !== toggle
    })
    step.hidden = false
    toggle.setAttribute("aria-expanded", "true")
    step.querySelector("input")?.focus()
  }

  choiceButtons() {
    return Array.from(this.choicesTarget.children)
  }

  hideSteps() {
    this.collectionStepTarget.hidden = true
    this.futureStepTarget.hidden = true
    this.collectionToggleTarget.setAttribute("aria-expanded", "false")
    this.futureToggleTarget.setAttribute("aria-expanded", "false")
  }
}
