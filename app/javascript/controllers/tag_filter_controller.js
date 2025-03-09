import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "tag"]

  filter() {
    const query = this.inputTarget.value.toLowerCase()

    this.tagTargets.forEach(tag => {
      const tagName = tag.textContent.toLowerCase()
      tag.style.display = tagName.includes(query) ? "" : "none"
    })
  }
}