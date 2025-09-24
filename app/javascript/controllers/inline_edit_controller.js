import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display", "form", "wordPhrase", "translation"]
  static values = { editing: Boolean }

  connect() {
    this.editingValue = false
  }

  edit(event) {
    event.preventDefault()
    this.editingValue = true
    this.updateDisplay()
  }

  cancel(event) {
    event.preventDefault()
    this.editingValue = false
    this.updateDisplay()
    this.resetForm()
  }

  updateDisplay() {
    if (this.editingValue) {
      this.displayTarget.classList.add("hidden")
      this.formTarget.classList.remove("hidden")
      // Focus on first input field
      const firstInput = this.formTarget.querySelector('input, textarea')
      if (firstInput) {
        firstInput.focus()
      }
    } else {
      this.displayTarget.classList.remove("hidden")
      this.formTarget.classList.add("hidden")
    }
  }

  resetForm() {
    const form = this.formTarget.querySelector('form')
    if (form) {
      form.reset()
    }
  }

  submitEnd(event) {
    // This is called after a successful turbo stream response
    if (event.detail.success !== false) {
      this.editingValue = false
      this.updateDisplay()
    }
  }
} 