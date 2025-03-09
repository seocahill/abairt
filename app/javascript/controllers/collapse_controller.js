import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "icon"]

  connect() {
    // Check if we're on mobile and hide content by default
    if (window.innerWidth < 768) {
      this.hide()
    }
  }

  toggle() {
    if (this.contentTarget.classList.contains("hidden")) {
      this.show()
    } else {
      this.hide()
    }
  }

  show() {
    this.contentTarget.classList.remove("hidden")
    this.iconTarget.classList.add("rotate-180")
  }

  hide() {
    this.contentTarget.classList.add("hidden")
    this.iconTarget.classList.remove("rotate-180")
  }
}