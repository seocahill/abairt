import { Controller } from "@hotwired/stimulus"
import RecordRTC from "recordrtc"

export default class extends Controller {
  static targets = ["recordButton", "stopButton", "status"]
  static values = { 
    mimeType: { type: String, default: "audio/webm" },
    timeLimit: { type: Number, default: 300000 } // 5 minutes default
  }

  connect() {
    this.isRecording = false
    this.updateUI()
  }

  async record(event) {
    event.preventDefault()
    
    if (this.isRecording) return

    try {
      this.stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      
      this.recorder = new RecordRTC(this.stream, {
        type: 'audio',
        mimeType: this.mimeTypeValue,
        recorderType: RecordRTC.StereoAudioRecorder,
        timeSlice: 1000,
        ondataavailable: (blob) => {
          this.dispatch("progress", { detail: { size: blob.size } })
        }
      })

      this.recorder.startRecording()
      this.isRecording = true
      this.updateUI()
      
      // Auto-stop after time limit
      this.autoStopTimer = setTimeout(() => {
        if (this.isRecording) {
          this.stop(new Event('timeout'))
        }
      }, this.timeLimitValue)

      this.dispatch("started")
      
    } catch (error) {
      console.error('Error accessing microphone:', error)
      this.dispatch("error", { detail: { error: error.message } })
    }
  }

  stop(event) {
    event.preventDefault()
    
    if (!this.isRecording) return

    this.recorder.stopRecording(() => {
      const blob = this.recorder.getBlob()
      
      // Cleanup recording resources
      this.cleanup()
      
      // Dispatch custom event with the audio blob
      this.element.dispatchEvent(new CustomEvent("audio:recorded", { 
        detail: { audioBlob: blob }, 
        bubbles: true 
      }))
      
      // Also dispatch the original recorded event for backward compatibility
      this.dispatch("recorded", { detail: { blob } })
    })
  }

  cancel(event) {
    event.preventDefault()
    this.cleanup()
    this.dispatch("cancelled")
  }

  cleanup() {
    this.isRecording = false
    
    if (this.autoStopTimer) {
      clearTimeout(this.autoStopTimer)
      this.autoStopTimer = null
    }
    
    if (this.stream) {
      this.stream.getTracks().forEach(track => track.stop())
      this.stream = null
    }
    
    if (this.recorder) {
      this.recorder.destroy()
      this.recorder = null
    }
    
    this.updateUI()
  }

  updateUI() {
    if (this.hasRecordButtonTarget) {
      this.recordButtonTarget.style.display = this.isRecording ? 'none' : 'block'
    }
    
    if (this.hasStopButtonTarget) {
      this.stopButtonTarget.style.display = this.isRecording ? 'block' : 'none'
    }
    
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = this.isRecording ? 'Recording...' : 'Ready'
    }
  }

  // Getter for current recording state
  get recording() {
    return this.isRecording
  }
} 