import { Controller } from "@hotwired/stimulus"

// A line in the transcript list. Tapping it asks the player (a separate part
// of the page) to jump to this line, via a window event the waveform
// controller listens for.
export default class extends Controller {
  static values = { start: Number, end: Number }

  seek(event) {
    // Leave editing, confirming and the line's own buttons alone.
    if (window.getSelection().toString()) return
    if (event.target.closest("[data-inline-edit-target='form']")) return
    if (event.target.closest("button, a, form, input, textarea, select, [data-action*=\"inline-edit#edit\"]")) return
    this.dispatch("seek", { prefix: "line", detail: { start: this.startValue, end: this.endValue } })
  }

  play(event) {
    this.dispatch("seek", { prefix: "line", detail: { start: this.startValue, end: this.endValue } })
  }
}
