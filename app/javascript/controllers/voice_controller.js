import { Controller } from "@hotwired/stimulus"

// Voice controller for mobile transcription correction interface
// Handles speech recognition, audio playback, and native bridge communication
export default class extends Controller {
  static targets = [
    "recordButton",
    "status",
    "conversation",
    "transcription",
    "translation",
    "originalAudio",
    "ttsAudio"
  ]

  static values = {
    sessionState: String,
    currentEntryId: Number
  }

  connect() {
    this.isRecording = false
    this.mediaRecorder = null
    this.audioChunks = []

    // Set up speech recognition if available
    this.setupSpeechRecognition()

    // Listen for response events from Turbo Stream
    window.addEventListener('voice:response', this.handleResponse.bind(this))

    // Check for native bridge (Turbo Native)
    this.hasNativeBridge = window.webkit?.messageHandlers?.nativeApp != null ||
                           window.nativeApp != null
  }

  disconnect() {
    window.removeEventListener('voice:response', this.handleResponse.bind(this))
    if (this.mediaRecorder) {
      this.mediaRecorder.stop()
    }
  }

  setupSpeechRecognition() {
    // Use Web Speech API for English voice commands
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition

    if (SpeechRecognition) {
      this.recognition = new SpeechRecognition()
      this.recognition.continuous = false
      this.recognition.interimResults = false
      this.recognition.lang = 'en-US'

      this.recognition.onresult = (event) => {
        const transcript = event.results[0][0].transcript
        this.sendTextInput(transcript)
      }

      this.recognition.onerror = (event) => {
        console.error('Speech recognition error:', event.error)
        this.updateStatus('Tap to speak')
        this.isRecording = false
        this.updateRecordButton()
      }

      this.recognition.onend = () => {
        if (this.isRecording) {
          this.isRecording = false
          this.updateRecordButton()
          this.updateStatus('Processing...')
        }
      }
    } else {
      // Fall back to MediaRecorder for audio capture
      this.useMediaRecorder = true
    }
  }

  toggleRecording() {
    if (this.isRecording) {
      this.stopRecording()
    } else {
      this.startRecording()
    }
  }

  startRecording() {
    this.isRecording = true
    this.updateRecordButton()
    this.updateStatus('Listening...')

    if (this.hasNativeBridge) {
      // Use native speech recognition
      this.sendToNative('startSpeechRecognition', {})
    } else if (this.recognition) {
      // Use Web Speech API
      this.recognition.start()
    } else if (this.useMediaRecorder) {
      // Fall back to audio recording
      this.startAudioRecording()
    }
  }

  stopRecording() {
    this.isRecording = false
    this.updateRecordButton()

    if (this.hasNativeBridge) {
      this.sendToNative('stopSpeechRecognition', {})
    } else if (this.recognition) {
      this.recognition.stop()
    } else if (this.mediaRecorder) {
      this.mediaRecorder.stop()
    }
  }

  async startAudioRecording() {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      this.mediaRecorder = new MediaRecorder(stream)
      this.audioChunks = []

      this.mediaRecorder.ondataavailable = (event) => {
        this.audioChunks.push(event.data)
      }

      this.mediaRecorder.onstop = () => {
        const audioBlob = new Blob(this.audioChunks, { type: 'audio/webm' })
        this.sendAudioInput(audioBlob)
        stream.getTracks().forEach(track => track.stop())
      }

      this.mediaRecorder.start()
    } catch (error) {
      console.error('Failed to start audio recording:', error)
      this.updateStatus('Microphone access denied')
      this.isRecording = false
      this.updateRecordButton()
    }
  }

  sendTextInput(text) {
    // Append user message to conversation immediately
    this.appendMessage('user', text)

    // Send to server
    const formData = new FormData()
    formData.append('text', text)

    fetch('/mobile/voice/process_input', {
      method: 'POST',
      headers: {
        'X-CSRF-Token': this.csrfToken(),
        'Accept': 'text/vnd.turbo-stream.html'
      },
      body: formData
    })
    .then(response => response.text())
    .then(html => {
      Turbo.renderStreamMessage(html)
    })
    .catch(error => {
      console.error('Failed to send input:', error)
      this.appendMessage('assistant', 'Sorry, something went wrong. Please try again.')
    })
  }

  sendAudioInput(audioBlob) {
    this.updateStatus('Processing audio...')

    const formData = new FormData()
    formData.append('audio', audioBlob, 'recording.webm')

    fetch('/mobile/voice/process_input', {
      method: 'POST',
      headers: {
        'X-CSRF-Token': this.csrfToken(),
        'Accept': 'text/vnd.turbo-stream.html'
      },
      body: formData
    })
    .then(response => response.text())
    .then(html => {
      Turbo.renderStreamMessage(html)
      this.updateStatus('Tap to speak')
    })
    .catch(error => {
      console.error('Failed to send audio:', error)
      this.updateStatus('Error - tap to try again')
    })
  }

  handleResponse(event) {
    const { action, data, sessionState, currentEntryId } = event.detail

    this.sessionStateValue = sessionState
    if (currentEntryId) {
      this.currentEntryIdValue = currentEntryId
    }

    switch (action) {
      case 'speak':
        // Speak Irish text using TTS
        if (data.irish_text) {
          this.speakIrishText(data.irish_text)
        }
        break
      case 'play_segment':
        // Play audio segment
        this.playSegment(data.entry_id)
        break
    }

    this.updateStatus('Tap to speak')
  }

  playOriginal() {
    if (this.hasOriginalAudioTarget) {
      // Get audio URL from current entry
      fetch(`/mobile/voice/play_segment/${this.currentEntryIdValue}`, {
        headers: { 'Accept': 'application/json' }
      })
      .then(response => response.json())
      .then(data => {
        this.originalAudioTarget.src = data.audio_url
        this.originalAudioTarget.play()
      })
    }
  }

  speakIrish() {
    const text = this.transcriptionTarget?.textContent?.trim()
    if (text) {
      this.speakIrishText(text)
    }
  }

  async speakIrishText(text) {
    // Fetch TTS audio from server
    try {
      const response = await fetch('/api/text_to_speech', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken()
        },
        body: JSON.stringify({ text: text })
      })

      const data = await response.json()
      if (data.audioContent) {
        // Play base64 audio
        const audio = new Audio(`data:audio/wav;base64,${data.audioContent}`)
        audio.play()
      }
    } catch (error) {
      console.error('Failed to speak Irish text:', error)
    }
  }

  speakEnglish(text) {
    // Use browser speech synthesis for English
    if ('speechSynthesis' in window) {
      const utterance = new SpeechSynthesisUtterance(text)
      utterance.lang = 'en-US'
      speechSynthesis.speak(utterance)
    }
  }

  reset() {
    fetch('/mobile/voice/reset', {
      method: 'POST',
      headers: {
        'X-CSRF-Token': this.csrfToken()
      }
    })
    .then(() => {
      window.location.reload()
    })
  }

  appendMessage(role, content) {
    if (this.hasConversationTarget) {
      const div = document.createElement('div')
      div.className = role === 'user' ? 'text-right' : 'text-left'
      div.innerHTML = `
        <div class="inline-block max-w-[80%] px-4 py-2 rounded-lg ${role === 'user' ? 'bg-blue-600' : 'bg-gray-700'}">
          ${this.escapeHtml(content)}
        </div>
      `
      this.conversationTarget.appendChild(div)
      this.conversationTarget.scrollTop = this.conversationTarget.scrollHeight
    }
  }

  updateRecordButton() {
    if (this.hasRecordButtonTarget) {
      if (this.isRecording) {
        this.recordButtonTarget.classList.add('bg-red-400', 'animate-pulse')
        this.recordButtonTarget.classList.remove('bg-red-600')
      } else {
        this.recordButtonTarget.classList.remove('bg-red-400', 'animate-pulse')
        this.recordButtonTarget.classList.add('bg-red-600')
      }
    }
  }

  updateStatus(text) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = text
    }
  }

  sendToNative(action, data) {
    if (window.webkit?.messageHandlers?.nativeApp) {
      window.webkit.messageHandlers.nativeApp.postMessage({ action, data })
    } else if (window.nativeApp) {
      window.nativeApp.postMessage(JSON.stringify({ action, data }))
    }
  }

  csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ''
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}
