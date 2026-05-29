import { Controller } from "@hotwired/stimulus"
import WaveSurfer from "wavesurferjs"
import RecordRTC from "recordrtc"
import { DirectUpload } from "@rails/activestorage"

// Drives the shadow-practice screen.
//
// Native audio is shown as a WaveSurfer waveform whose progress cursor
// doubles as the timing cue for the two modes:
//   echo  - listen first; recording starts when the cursor reaches the end.
//   sync  - recording starts at the same instant as native playback.
//
// Capture is self-contained (RecordRTC) so we can pre-warm the microphone
// stream on the first Start click and hold it across takes — this is what
// lets Sync actually start tight with the native audio instead of trailing
// behind getUserMedia by a second or two.
export default class extends Controller {
  static targets = [
    "waveform", "speed", "listenButton",
    "modeButton", "headphonesTip",
    "startButton", "stopButton", "status",
    "playTakeButton", "takeAudio"
  ]
  static values = {
    nativeUrl: String,
    directUploadUrl: String,
    createUrl: String,
    entryId: Number,
    mode: { type: String, default: "echo" }
  }

  connect() {
    this.initWaveform()
    this.applyMode()
  }

  disconnect() {
    this.cleanupFinishHandler()
    if (this.waveSurfer) this.waveSurfer.destroy()
    if (this.recorder) { this.recorder.destroy(); this.recorder = null }
    this.releaseStream()
    if (this.takeUrl) URL.revokeObjectURL(this.takeUrl)
  }

  // --- WaveSurfer (native audio) -----------------------------------------

  initWaveform() {
    this.waveSurfer = WaveSurfer.create({
      container: this.waveformTarget,
      waveColor: "#9ca3af",
      progressColor: "#4F46E5",
      cursorColor: "#312E81",
      barWidth: 2,
      barRadius: 3,
      cursorWidth: 1,
      height: 80,
      barGap: 3,
      responsive: true,
      normalize: true,
      backend: "MediaElement"
    })
    this.waveSurfer.load(this.nativeUrlValue)
  }

  listen(event) {
    event?.preventDefault()
    this.waveSurfer?.playPause()
  }

  changeSpeed(event) {
    event?.preventDefault()
    const rate = parseFloat(event.currentTarget.value)
    if (this.waveSurfer && !Number.isNaN(rate)) this.waveSurfer.setPlaybackRate(rate)
  }

  // --- Mode toggle -------------------------------------------------------

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
    if (this.hasHeadphonesTipTarget) {
      this.headphonesTipTarget.classList.toggle("hidden", this.modeValue !== "sync")
    }
  }

  // --- Practice loop -----------------------------------------------------

  async start(event) {
    event?.preventDefault()
    this.toggleRecordingControls(true)
    if (this.hasPlayTakeButtonTarget) this.playTakeButtonTarget.disabled = true

    try {
      await this.ensureStream()
    } catch {
      this.setStatus("Microphone unavailable — check browser permissions", "error")
      this.toggleRecordingControls(false)
      return
    }

    if (this.modeValue === "echo") {
      this.setStatus("Listen…", "listen")
      this.cleanupFinishHandler()
      this._finishHandler = async () => {
        this._finishHandler = null
        this.setStatus("Speak now ▸", "speak")
        await this.startCapture()
      }
      this.waveSurfer.once("finish", this._finishHandler)
      this.waveSurfer.seekTo(0)
      this.waveSurfer.play()
    } else {
      // sync: have the recorder running before native playback begins
      this.setStatus("Get ready…", "listen")
      await this.startCapture()
      this.setStatus("Speak along now ▸", "speak")
      this.waveSurfer.seekTo(0)
      this.waveSurfer.play()
    }
  }

  async stop(event) {
    event?.preventDefault()
    this.cleanupFinishHandler()
    if (this.waveSurfer?.isPlaying()) this.waveSurfer.pause()
    const blob = await this.stopCapture()
    this.toggleRecordingControls(false)
    if (blob) {
      this.handleRecorded(blob)
    } else {
      this.setStatus("Ready")
    }
  }

  handleRecorded(blob) {
    if (this.takeUrl) URL.revokeObjectURL(this.takeUrl)
    this.takeUrl = URL.createObjectURL(blob)
    if (this.hasTakeAudioTarget) this.takeAudioTarget.src = this.takeUrl
    if (this.hasPlayTakeButtonTarget) this.playTakeButtonTarget.disabled = false
    this.setStatus("Saving…")
    this.persist(blob)
  }

  playTake(event) {
    event?.preventDefault()
    if (!this.takeUrl) return
    this.takeAudioTarget.currentTime = 0
    this.takeAudioTarget.play()
  }

  // --- Microphone capture (pre-warmed) -----------------------------------

  async ensureStream() {
    if (this.stream && this.stream.active) return this.stream
    this.stream = await navigator.mediaDevices.getUserMedia({ audio: true })
    return this.stream
  }

  releaseStream() {
    if (this.stream) {
      this.stream.getTracks().forEach((t) => t.stop())
      this.stream = null
    }
  }

  async startCapture() {
    await this.ensureStream()
    this.recorder = new RecordRTC(this.stream, {
      type: "audio",
      mimeType: "audio/webm",
      recorderType: RecordRTC.StereoAudioRecorder
    })
    this.recorder.startRecording()
  }

  stopCapture() {
    return new Promise((resolve) => {
      if (!this.recorder) return resolve(null)
      this.recorder.stopRecording(() => {
        const blob = this.recorder.getBlob()
        this.recorder.destroy()
        this.recorder = null
        resolve(blob)
      })
    })
  }

  // --- Persistence -------------------------------------------------------

  persist(blob) {
    const file = new File([blob], "shadow.webm", { type: blob.type })
    const upload = new DirectUpload(file, this.directUploadUrlValue)
    upload.create((error, uploaded) => {
      if (error) { this.setStatus("Save failed", "error"); return }
      const body = new FormData()
      body.append("dictionary_entry_id", this.entryIdValue)
      body.append("media", uploaded.signed_id)
      fetch(this.createUrlValue, {
        method: "POST",
        body,
        headers: { "X-CSRF-Token": this.csrfToken },
        credentials: "same-origin"
      })
        .then((response) => this.setStatus(response.ok ? "Saved" : "Save failed", response.ok ? null : "error"))
        .catch(() => this.setStatus("Save failed", "error"))
    })
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }

  // --- UI helpers --------------------------------------------------------

  cleanupFinishHandler() {
    if (this._finishHandler && this.waveSurfer) {
      this.waveSurfer.un("finish", this._finishHandler)
    }
    this._finishHandler = null
  }

  toggleRecordingControls(recording) {
    if (this.hasStartButtonTarget) this.startButtonTarget.classList.toggle("hidden", recording)
    if (this.hasStopButtonTarget) this.stopButtonTarget.classList.toggle("hidden", !recording)
  }

  setStatus(text, tone = null) {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = text
    this.statusTarget.classList.remove("text-gray-500", "text-blue-600", "text-red-600", "font-semibold", "animate-pulse")
    if (tone === "speak") {
      this.statusTarget.classList.add("text-blue-600", "font-semibold", "animate-pulse")
    } else if (tone === "listen") {
      this.statusTarget.classList.add("text-blue-600")
    } else if (tone === "error") {
      this.statusTarget.classList.add("text-red-600")
    } else {
      this.statusTarget.classList.add("text-gray-500")
    }
  }
}
