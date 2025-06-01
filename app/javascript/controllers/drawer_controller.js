import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["drawer", "backdrop"]

  connect() {
    // Add event listener for ESC key to close drawer
    document.addEventListener('keydown', this.handleKeyDown.bind(this))
  }

  disconnect() {
    // Remove event listener when controller is disconnected
    document.removeEventListener('keydown', this.handleKeyDown.bind(this))
  }

  handleKeyDown(event) {
    if (event.key === 'Escape' && this.drawerTarget.classList.contains('translate-x-0')) {
      this.close()
    }
  }

  toggle(event) {
    event.preventDefault()
    if (this.drawerTarget.classList.contains('translate-x-0')) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.drawerTarget.classList.remove('translate-x-full')
    this.drawerTarget.classList.add('translate-x-0')
    this.backdropTarget.classList.add('show')
    document.body.classList.add('drawer-open')
  }

  close() {
    this.drawerTarget.classList.remove('translate-x-0')
    this.drawerTarget.classList.add('translate-x-full')
    this.backdropTarget.classList.remove('show')
    document.body.classList.remove('drawer-open')
  }
}