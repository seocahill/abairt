import { Controller } from "stimulus"

export default class extends Controller {
  static targets = ["cell"]

  hide() {
    this.cellTargets.forEach((cellTarget) => {
      cellTarget.classList.toggle("hidden")
    })
  }
}
