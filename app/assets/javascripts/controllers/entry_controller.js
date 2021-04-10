import { Controller } from "stimulus"

export default class extends Controller {
  static targets = ["dropdown", "audio"]

  connect() {
  }

  teardown() {
  }

  play(e) {
    e.preventDefault()
    this.audioTarget.play()
  }

  show() {
    this.dropdownTarget.classList.remove("hidden")
  }

  hide() {
    this.dropdownTarget.classList.add("hidden")
  }
}
