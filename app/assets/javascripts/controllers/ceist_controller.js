import { Controller } from "stimulus"

export default class extends Controller {
  static targets = ["answer"]

  show() {
    this.answerTarget.classList.remove("hidden")
  }
}
