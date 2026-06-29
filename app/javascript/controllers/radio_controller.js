import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "audio", "title", "link", "ga", "en",
    "playButton", "playIcon", "pauseIcon",
    "progress", "currentTime", "duration", "position"
  ]
  static values = { playlist: Array }

  connect() {
    this.order = this.shuffledOrder()
    this.cursor = 0
    this.loadCurrent({ autoplay: false })
  }

  disconnect() {
    if (this.hasAudioTarget) {
      this.audioTarget.pause()
      this.audioTarget.removeAttribute("src")
      this.audioTarget.load()
    }
  }

  // ── Playlist navigation ──────────────────────────────────────────────────

  shuffledOrder() {
    const indices = this.playlistValue.map((_, i) => i)
    for (let i = indices.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1))
      ;[indices[i], indices[j]] = [indices[j], indices[i]]
    }
    return indices
  }

  current() {
    return this.playlistValue[this.order[this.cursor]]
  }

  loadCurrent({ autoplay = true } = {}) {
    const item = this.current()
    if (!item) return

    this.audioTarget.src = item.url
    if (this.hasTitleTarget) this.titleTarget.textContent = item.title
    if (this.hasLinkTarget) this.linkTarget.href = item.path
    if (this.hasPositionTarget) this.positionTarget.textContent = String(this.cursor + 1)

    this.resetCaption()
    this.resetProgress()

    if (autoplay) {
      const play = this.audioTarget.play()
      if (play && typeof play.catch === "function") play.catch(() => {})
    }
  }

  next() {
    if (this.playlistValue.length === 0) return
    this.cursor = (this.cursor + 1) % this.order.length
    this.loadCurrent()
  }

  prev() {
    if (this.playlistValue.length === 0) return
    this.cursor = (this.cursor - 1 + this.order.length) % this.order.length
    this.loadCurrent()
  }

  shuffle() {
    this.order = this.shuffledOrder()
    this.cursor = 0
    this.loadCurrent()
  }

  // ── Playback ─────────────────────────────────────────────────────────────

  playPause() {
    if (this.audioTarget.paused) {
      const play = this.audioTarget.play()
      if (play && typeof play.catch === "function") play.catch(() => {})
    } else {
      this.audioTarget.pause()
    }
  }

  playing() {
    this.playIconTarget?.classList.add("hidden")
    this.pauseIconTarget?.classList.remove("hidden")
    this.playButtonTarget?.setAttribute("aria-label", "Pause")
  }

  paused() {
    this.playIconTarget?.classList.remove("hidden")
    this.pauseIconTarget?.classList.add("hidden")
    this.playButtonTarget?.setAttribute("aria-label", "Play")
  }

  // ── Progress and captions ────────────────────────────────────────────────

  timeupdate() {
    const t = this.audioTarget.currentTime
    const total = this.audioTarget.duration || 0
    if (this.hasProgressTarget && total > 0) {
      this.progressTarget.style.width = `${Math.min(100, (t / total) * 100)}%`
    }
    if (this.hasCurrentTimeTarget) {
      this.currentTimeTarget.textContent = this.formatTime(t)
    }

    const entries = this.current()?.entries || []
    const entry = entries.find((e) => t >= e.start && t < e.end)
    if (entry) {
      if (this.hasGaTarget && entry.ga) this.gaTarget.textContent = entry.ga
      if (this.hasEnTarget) this.enTarget.textContent = entry.en || ""
    }
  }

  loadedmetadata() {
    if (this.hasDurationTarget) {
      this.durationTarget.textContent = this.formatTime(this.audioTarget.duration)
    }
  }

  resetCaption() {
    if (this.hasGaTarget) this.gaTarget.textContent = this.current()?.title || ""
    if (this.hasEnTarget) this.enTarget.textContent = ""
  }

  resetProgress() {
    if (this.hasProgressTarget) this.progressTarget.style.width = "0%"
    if (this.hasCurrentTimeTarget) this.currentTimeTarget.textContent = "0:00"
    if (this.hasDurationTarget) this.durationTarget.textContent = "0:00"
  }

  formatTime(seconds) {
    if (!Number.isFinite(seconds)) return "0:00"
    const m = Math.floor(seconds / 60)
    const s = Math.floor(seconds % 60).toString().padStart(2, "0")
    return `${m}:${s}`
  }
}
