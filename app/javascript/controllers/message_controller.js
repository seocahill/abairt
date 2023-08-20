import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["deleteButton"];
  static values = { userId: String }

  connect() {
    this.element.scrollIntoView()
    // align chats
    const currentUserId = document.getElementById('rang').dataset.currentUserId
    if (currentUserId === this.userIdValue) {
      this.element.classList.add('justify-end')
    } else {
      this.element.classList.add('justify-start')
    }
  }

  showDeleteButton() {
    if (this.hasDeleteButtonTarget) {
      this.deleteButtonTarget.style.opacity = "1";
    }
  }

  hideDeleteButton() {
    if (this.hasDeleteButtonTarget) {
      this.deleteButtonTarget.style.opacity = "0";
    }
  }
}
