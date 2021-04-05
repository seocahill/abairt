import { Controller } from "stimulus"

export default class extends Controller {
  static targets = ["dropdown"]

  connect() {
    console.log('hello fro entry')
  }

  teardown() {
    console.log('goodby fro entry')
  }

  show() {
    this.dropdownTarget.classList.toggle("hidden")
  }
}
