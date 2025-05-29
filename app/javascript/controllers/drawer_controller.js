import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["drawer", "backdrop"]

  connect() {
    // Create backdrop if it doesn't exist
    // if (!this.hasBackdropTarget) {
    //   const backdrop = document.createElement('div')
    //   backdrop.classList.add('drawer-backdrop')
    //   backdrop.setAttribute('data-drawer-target', 'backdrop')
    //   backdrop.addEventListener('click', () => this.close())
    //   document.body.appendChild(backdrop)
    // }
  }

  toggle() {
    if (this.drawerTarget.classList.contains('drawer-show')) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.drawerTarget.classList.add('drawer-show')
    this.backdropTarget.classList.add('show')
    document.body.classList.add('drawer-open')
  }

  close() {
    this.drawerTarget.classList.remove('drawer-show')
    this.backdropTarget.classList.remove('show')
    document.body.classList.remove('drawer-open')
  }
}