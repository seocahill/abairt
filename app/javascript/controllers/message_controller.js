import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { userId: String }
  connect() {
    this.element.scrollIntoView()
    // align chats
    const currentUserId = document.getElementById('rang').dataset.currentUserId
    console.log(currentUserId, this.userIdValue)
    if (currentUserId === this.userIdValue) {
      this.element.classList.add('justify-end')
    } else {
      this.element.classList.add('justify-start')
    }
  }
}
