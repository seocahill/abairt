import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["drawer"]

  connect() {
    document.addEventListener('keydown', this.handleKeyDown.bind(this))
  }

  disconnect() {
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
  }

  close() {
    this.drawerTarget.classList.remove('translate-x-0')
    this.drawerTarget.classList.add('translate-x-full')
  }
}