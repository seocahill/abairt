import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Hold the button, speak, let go. The question is sent on release — there is no
// separate send step, because the whole point is that a question occurs to you
// mid-conversation with your kid and you have one hand free.
export default class extends Controller {
  static targets = ["button", "status", "timer"]
  static values = {
    url: String,
    maxSeconds: { type: Number, default: 60 },
    minSeconds: { type: Number, default: 0.4 }
  }

  connect() {
    this.recording = false
    this.setStatus("Brúigh agus coinnigh")
  }

  disconnect() {
    this.releaseMicrophone()
  }

  // --- press and release -----------------------------------------------------

  async start(event) {
    event.preventDefault()
    if (this.recording || this.sending) return

    try {
      this.stream = await navigator.mediaDevices.getUserMedia({ audio: true })
    } catch (error) {
      return this.setStatus("Níl cead ag an micreafón.", "error")
    }

    this.chunks = []
    this.recorder = new MediaRecorder(this.stream)
    this.recorder.ondataavailable = (event) => this.chunks.push(event.data)
    this.recorder.onstop = () => this.send()
    this.recorder.start()

    this.recording = true
    this.startedAt = Date.now()
    this.buttonTarget.classList.add("recording")
    this.setStatus("Ag éisteacht…", "recording")
    this.tick()

    // Don't let a pocket or a distraction record forever.
    this.autoStop = setTimeout(() => this.stop(new Event("timeout")), this.maxSecondsValue * 1000)
  }

  stop(event) {
    event.preventDefault()
    if (!this.recording) return

    this.recording = false
    clearTimeout(this.autoStop)
    clearInterval(this.ticker)
    this.buttonTarget.classList.remove("recording")
    this.recorder.stop()
  }

  // --- sending --------------------------------------------------------------

  async send() {
    const elapsed = (Date.now() - this.startedAt) / 1000
    this.releaseMicrophone()
    this.timerTarget.textContent = ""

    // A stray tap is not a question.
    if (elapsed < this.minSecondsValue) {
      return this.setStatus("Coinnigh síos é agus labhair.", "hint")
    }

    this.sending = true
    this.setStatus("Á sheoladh…", "sending")

    const body = new FormData()
    body.append("audio", new Blob(this.chunks, { type: this.recorder.mimeType }), this.filename())

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        body: body,
        headers: {
          "X-CSRF-Token": this.csrfToken(),
          "Accept": "text/vnd.turbo-stream.html"
        }
      })

      if (!response.ok) throw new Error(response.status)

      Turbo.renderStreamMessage(await response.text())
      this.setStatus("Éist leis, ansin seol é.", "recorded")
    } catch (error) {
      // The recording is gone at this point, so say so plainly rather than
      // pretending it is queued.
      this.setStatus("Theip ar an seoladh. Bain triail eile as.", "error")
    } finally {
      this.sending = false
    }
  }

  // --- helpers --------------------------------------------------------------

  tick() {
    this.ticker = setInterval(() => {
      const seconds = Math.floor((Date.now() - this.startedAt) / 1000)
      this.timerTarget.textContent = `0:${String(seconds).padStart(2, "0")}`
    }, 250)
  }

  releaseMicrophone() {
    clearTimeout(this.autoStop)
    clearInterval(this.ticker)
    this.stream?.getTracks().forEach((track) => track.stop())
    this.stream = null
  }

  filename() {
    const extension = this.recorder.mimeType.includes("mp4") ? "m4a" : "webm"
    return `ceist.${extension}`
  }

  csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }

  setStatus(message, state = "ready") {
    this.statusTarget.textContent = message
    this.statusTarget.dataset.state = state
  }
}
