import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container"]

  connect() {
    // Bind the escape key handler
    this.escapeHandler = (event) => {
      if (event.key === "Escape") {
        this.close()
      }
    }
    // Bind the click outside handler with the correct context
    this.clickOutsideHandler = this.clickOutside.bind(this)
  }

  open() {
    this.containerTarget.classList.remove("hidden")
    document.body.style.overflow = "hidden" // Prevent scrolling when modal is open

    // Add event listeners when modal opens
    document.addEventListener("keydown", this.escapeHandler)
    document.addEventListener("click", this.clickOutsideHandler)
  }

  close() {
    this.containerTarget.classList.add("hidden")
    document.body.style.overflow = "" // Restore scrolling

    // Remove event listeners when modal closes
    document.removeEventListener("keydown", this.escapeHandler)
    document.removeEventListener("click", this.clickOutsideHandler)
  }

  clickOutside(event) {
    // Check if the click was outside the modal content
    if (event.target === this.containerTarget) {
      this.close()
    }
  }

  disconnect() {
    // Clean up event listeners when controller is disconnected
    document.removeEventListener("keydown", this.escapeHandler)
    document.removeEventListener("click", this.clickOutsideHandler)
    document.body.style.overflow = "" // Restore scrolling
  }
}