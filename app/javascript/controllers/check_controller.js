import { Controller } from "@hotwired/stimulus"

// Check mode (f140_check_mode): plays the line, and handles the keys.
// Enter in a field confirms and moves on; Shift+Enter is a new line.
// Tab and Shift+Tab keep their normal job (moving between the fields), so
// skipping uses Alt+Arrow and replaying Alt+R (Ctrl+Arrow and Ctrl+R belong to
// the text field and the browser).
export default class extends Controller {
  static targets = ["audio", "form", "loop"]
  static values = { previousUrl: String, nextUrl: String, exitUrl: String, start: Number, end: Number }

  connect() {
    this.onKey = this.key.bind(this)
    document.addEventListener("keydown", this.onKey)
    this.onTime = this.timeUpdate.bind(this)
    this.audioTarget.addEventListener("timeupdate", this.onTime)
    this.replay()
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKey)
    this.audioTarget.pause()
    this.audioTarget.removeEventListener("timeupdate", this.onTime)
  }

  replay() {
    const audio = this.audioTarget
    const start = () => { audio.currentTime = this.startValue; audio.play().catch(() => {}) }
    if (audio.readyState >= 1) start()
    else audio.addEventListener("loadedmetadata", start, { once: true })
  }

  toggleLoop() {
    this.looping = this.loopTarget.checked
    this.audioTarget.loop = this.looping && !this.endValue
    if (this.looping) this.replay()
  }

  fieldKey(event) {
    if (event.key === "Enter" && !event.shiftKey && !event.isComposing) {
      event.preventDefault()
      this.formTarget.requestSubmit()
    }
  }

  key(event) {
    if (event.key === "Escape") return this.go(this.exitUrlValue)
    if (!event.altKey) return
    if (event.key.toLowerCase() === "r") { event.preventDefault(); this.replay() }
    if (event.key === "ArrowRight") { event.preventDefault(); this.go(this.nextUrlValue) }
    if (event.key === "ArrowLeft") { event.preventDefault(); this.go(this.previousUrlValue) }
  }

  // A line cut from the whole recording stops at its end; its own snippet ends by itself.
  timeUpdate() {
    if (!this.endValue || this.audioTarget.currentTime < this.endValue) return
    this.audioTarget.pause()
    if (this.looping) this.replay()
  }

  go(url) {
    if (url) window.Turbo.visit(url)
  }
}
