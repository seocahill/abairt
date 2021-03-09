import { Controller } from "stimulus"

export default class extends Controller {
  reset() {
    //Fixme
    this.element.elements['dictionary_entry[media]'].forEach((item) => {
      if (item.type === "hidden") {
        item.remove()
      }
    })
    this.element.reset()
  }
}
