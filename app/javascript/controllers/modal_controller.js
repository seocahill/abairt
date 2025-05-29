import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container"]

  connect() {
    // Add event listener for ESC key to close modal
    document.addEventListener('keydown', this.handleKeyDown.bind(this))
  }

  disconnect() {
    // Remove event listener when controller is disconnected
    document.removeEventListener('keydown', this.handleKeyDown.bind(this))
  }

  handleKeyDown(event) {
    if (event.key === 'Escape' && !this.containerTarget.classList.contains('hidden')) {
      this.close()
    }
  }

  open() {
    this.containerTarget.classList.remove('hidden')
    document.body.classList.add('overflow-hidden')
  }

  close() {
    this.containerTarget.classList.add('hidden')
    document.body.classList.remove('overflow-hidden')
  }
}