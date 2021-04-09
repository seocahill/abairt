import { Controller } from "stimulus"

export default class extends Controller {
  static targets = ["answer", "buttons"]

  show() {
    this.answerTarget.classList.remove("hidden")
    this.buttonsTarget.classList.remove("hidden")
  }
}
