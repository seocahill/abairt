import { Controller } from "stimulus"

export default class extends Controller {
  reset() {
    this.element.elements[5].remove()
    this.element.reset()
  }
}
