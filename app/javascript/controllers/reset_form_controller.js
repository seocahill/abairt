import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  reset() {
    if (this.element.elements['dictionary_entry[media]'] instanceof RadioNodeList) {
      this.element.elements['dictionary_entry[media]'].forEach((item) => {
        if (item.type === "hidden") {
          item.remove()
        }
      })
    }
    this.element.reset()
  }
}
