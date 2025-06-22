import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { message: String }

  connect() {
    this.element.addEventListener('submit', this.confirm.bind(this))
  }

  confirm(event) {
    if (!window.confirm(this.messageValue)) {
      event.preventDefault()
    }
  }
}