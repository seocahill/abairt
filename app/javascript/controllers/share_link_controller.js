import { Controller } from "@hotwired/stimulus"

// Shares a link: the phone's share sheet where there is one, the clipboard
// otherwise. A "Share at current time" button passes `useCurrentTime` and the
// link is built from where the player is.
export default class extends Controller {
  static targets = ["label"]
  static values = { url: String, title: String, label: String, useCurrentTime: Boolean }

  async share() {
    const url = this.link()

    if (navigator.share) {
      try {
        await navigator.share({ title: this.titleValue, url })
        return
      } catch (error) {
        if (error.name === "AbortError") return
      }
    }

    await this.copy(url)
  }

  link() {
    if (!this.useCurrentTimeValue) return this.urlValue

    const seconds = this.currentSeconds()
    const url = new URL(this.urlValue, window.location.href)
    url.searchParams.set("t", seconds.toFixed(1))
    return url.toString()
  }

  currentSeconds() {
    const el = document.querySelector('[data-controller~="waveform"]')
    const waveform = el && this.application.getControllerForElementAndIdentifier(el, "waveform")
    return waveform?.currentTime() || 0
  }

  async copy(url) {
    try {
      await navigator.clipboard.writeText(url)
      this.flash("Link copied")
    } catch {
      window.prompt("Copy this link", url)
    }
  }

  flash(message) {
    if (!this.hasLabelTarget) return
    this.labelTarget.textContent = message
    clearTimeout(this.timer)
    this.timer = setTimeout(() => { this.labelTarget.textContent = this.labelValue }, 2000)
  }
}
