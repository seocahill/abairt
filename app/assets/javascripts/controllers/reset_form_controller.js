import { Controller } from "stimulus"

export default class extends Controller {
  reset() {
    //Fixme
    // this.element.elements[4].remove()
    this.element.reset()
  }
}
