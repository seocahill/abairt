import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "playIcon", "pauseIcon", "progress", "time"]
  static values = { url: String }

  connect() {
    this.playing = false
  }

  disconnect() {
    if (this.audio) {
      this.audio.pause()
      this.audio = null
    }
  }

  toggle() {
    if (!this.audio) {
      this.audio = new Audio(this.urlValue)
      this.audio.preload = "none"
      this.audio.addEventListener("timeupdate", () => this.updateProgress())
      this.audio.addEventListener("ended", () => this.stop())
    }

    if (this.playing) {
      this.audio.pause()
      this.showPlay()
    } else {
      // Pause any other playing cards
      document.querySelectorAll("[data-controller='card-player']").forEach(el => {
        if (el !== this.element) {
          const ctrl = this.application.getControllerForElementAndIdentifier(el, "card-player")
          if (ctrl?.playing) ctrl.stop()
        }
      })
      this.audio.play()
      this.showPause()
    }
  }

  stop() {
    if (this.audio) this.audio.pause()
    this.showPlay()
    if (this.hasProgressTarget) this.progressTarget.style.width = "0%"
  }

  updateProgress() {
    if (!this.audio || !this.audio.duration) return
    const pct = (this.audio.currentTime / this.audio.duration) * 100
    if (this.hasProgressTarget) this.progressTarget.style.width = `${pct}%`
    if (this.hasTimeTarget) this.timeTarget.textContent = this.formatTime(this.audio.currentTime)
  }

  showPlay() {
    this.playing = false
    if (this.hasPlayIconTarget) this.playIconTarget.classList.remove("hidden")
    if (this.hasPauseIconTarget) this.pauseIconTarget.classList.add("hidden")
  }

  showPause() {
    this.playing = true
    if (this.hasPlayIconTarget) this.playIconTarget.classList.add("hidden")
    if (this.hasPauseIconTarget) this.pauseIconTarget.classList.remove("hidden")
  }

  formatTime(s) {
    const m = Math.floor(s / 60)
    return `${m}:${String(Math.floor(s % 60)).padStart(2, "0")}`
  }
}
