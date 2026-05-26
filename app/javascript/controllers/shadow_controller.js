import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage"

// Drives the shadow-practice screen: plays the native phrase, orchestrates the
// echo/sync/blind modes, and records the learner repeating it. Recording itself
// is delegated to the audio-recorder controller on the same element; this
// controller listens for its `audio:recorded` event, plays the take back
// instantly, and persists it via the practice_recordings endpoint.
export default class extends Controller {
  static targets = ["text", "status", "startButton", "stopButton", "playTakeButton", "takeAudio", "modeButton"]
  static values = {
    nativeUrl: String,
    directUploadUrl: String,
    createUrl: String,
    entryId: Number,
    mode: { type: String, default: "echo" }
  }

  connect() {
    this.native = new Audio(this.nativeUrlValue)
    this.native.preload = "auto"
    this.onRecorded = this.onRecorded.bind(this)
    this.onRecorderError = this.onRecorderError.bind(this)
    this.element.addEventListener("audio:recorded", this.onRecorded)
    this.element.addEventListener("audio-recorder:error", this.onRecorderError)
    this.applyMode()
  }

  disconnect() {
    this.element.removeEventListener("audio:recorded", this.onRecorded)
    this.element.removeEventListener("audio-recorder:error", this.onRecorderError)
    this.native?.pause()
    if (this.takeUrl) URL.revokeObjectURL(this.takeUrl)
  }

  // The audio-recorder controller instance sharing this element.
  get recorder() {
    return this.application.getControllerForElementAndIdentifier(this.element, "audio-recorder")
  }

  selectMode(event) {
    this.modeValue = event.currentTarget.dataset.mode
  }

  modeValueChanged() {
    this.applyMode()
  }

  applyMode() {
    this.modeButtonTargets.forEach((button) => {
      const active = button.dataset.mode === this.modeValue
      button.classList.toggle("bg-blue-600", active)
      button.classList.toggle("text-white", active)
      button.classList.toggle("border-blue-600", active)
    })
    if (this.hasTextTarget) {
      this.textTarget.classList.toggle("invisible", this.modeValue === "blind")
    }
  }

  playNative(event) {
    event?.preventDefault()
    this.native.currentTime = 0
    this.native.play()
  }

  start(event) {
    event?.preventDefault()
    this.toggleRecordingControls(true)
    if (this.hasPlayTakeButtonTarget) this.playTakeButtonTarget.disabled = true

    if (this.modeValue === "echo") {
      this.setStatus("Listen…")
      this.native.currentTime = 0
      this.native.onended = () => {
        this.native.onended = null
        this.beginRecording()
      }
      this.native.play()
    } else {
      // sync / blind: record while the native audio plays
      this.beginRecording()
      this.native.currentTime = 0
      this.native.play()
    }
  }

  beginRecording() {
    this.setStatus("Recording — repeat now")
    this.recorder.record(new Event("shadow:record"))
  }

  stop(event) {
    event?.preventDefault()
    this.native.onended = null
    this.native.pause()
    if (this.recorder?.recording) {
      this.recorder.stop(new Event("shadow:stop"))
    } else {
      this.setStatus("Ready")
    }
    this.toggleRecordingControls(false)
  }

  onRecorded(event) {
    const blob = event.detail.audioBlob
    if (this.takeUrl) URL.revokeObjectURL(this.takeUrl)
    this.takeUrl = URL.createObjectURL(blob)
    if (this.hasTakeAudioTarget) this.takeAudioTarget.src = this.takeUrl
    if (this.hasPlayTakeButtonTarget) this.playTakeButtonTarget.disabled = false
    this.setStatus("Saving…")
    this.persist(blob)
  }

  onRecorderError() {
    this.setStatus("Microphone unavailable — check browser permissions")
    this.toggleRecordingControls(false)
  }

  playTake(event) {
    event?.preventDefault()
    if (!this.takeUrl) return
    this.takeAudioTarget.currentTime = 0
    this.takeAudioTarget.play()
  }

  persist(blob) {
    const file = new File([blob], "shadow.webm", { type: blob.type })
    const upload = new DirectUpload(file, this.directUploadUrlValue)
    upload.create((error, uploaded) => {
      if (error) {
        this.setStatus("Save failed")
        return
      }
      const body = new FormData()
      body.append("dictionary_entry_id", this.entryIdValue)
      body.append("media", uploaded.signed_id)
      fetch(this.createUrlValue, {
        method: "POST",
        body,
        headers: { "X-CSRF-Token": this.csrfToken },
        credentials: "same-origin"
      })
        .then((response) => this.setStatus(response.ok ? "Saved" : "Save failed"))
        .catch(() => this.setStatus("Save failed"))
    })
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }

  toggleRecordingControls(recording) {
    if (this.hasStartButtonTarget) this.startButtonTarget.classList.toggle("hidden", recording)
    if (this.hasStopButtonTarget) this.stopButtonTarget.classList.toggle("hidden", !recording)
  }

  setStatus(text) {
    if (this.hasStatusTarget) this.statusTarget.textContent = text
  }
}
