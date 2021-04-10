import { Controller } from "stimulus"

export default class extends Controller {
  static targets = ["dropdown"]

  connect() {
  }

  teardown() {
  }

  show() {
    this.dropdownTarget.classList.remove("hidden")
  }

  hide() {
    this.dropdownTarget.classList.add("hidden")
  }
}
