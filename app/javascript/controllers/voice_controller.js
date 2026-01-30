import { Controller } from "@hotwired/stimulus"

// Voice controller for mobile transcription correction interface
// Handles speech recognition, audio playback, and TTS for both English and Irish
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
    this.audioQueue = []
    this.isPlayingAudio = false

    this.setupSpeechRecognition()
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
    speechSynthesis.cancel()
  }

  setupSpeechRecognition() {
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
    // Stop any playing audio first
    speechSynthesis.cancel()
    this.stopAllAudio()

    this.isRecording = true
    this.updateRecordButton()
    this.updateStatus('Listening...')

    if (this.hasNativeBridge) {
      this.sendToNative('startSpeechRecognition', {})
    } else if (this.recognition) {
      this.recognition.start()
    } else if (this.useMediaRecorder) {
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
    this.appendMessage('user', text)

    const formData = new FormData()
    formData.append('text', text)

    fetch('/mobile/voice/process_input', {
      method: 'POST',
      headers: {
        'X-CSRF-Token': this.csrfToken(),
        'Accept': 'application/json'
      },
      body: formData
    })
    .then(response => response.json())
    .then(data => this.processResponse(data))
    .catch(error => {
      console.error('Failed to send input:', error)
      this.speakEnglish('Sorry, something went wrong. Please try again.')
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
        'Accept': 'application/json'
      },
      body: formData
    })
    .then(response => response.json())
    .then(data => this.processResponse(data))
    .catch(error => {
      console.error('Failed to send audio:', error)
      this.updateStatus('Error - tap to try again')
      this.speakEnglish('Sorry, I had trouble processing that.')
    })
  }

  processResponse(data) {
    const { text, action, data: actionData, speak_english, currentEntryId } = data

    // Update current entry ID if provided
    if (currentEntryId) {
      this.currentEntryIdValue = currentEntryId
    }

    // Show assistant message
    this.appendMessage('assistant', text)
    this.updateStatus('Tap to speak')

    // Queue up audio to play
    this.audioQueue = []

    // First: speak the English response
    if (speak_english) {
      this.audioQueue.push({ type: 'english', text: speak_english })
    }

    // Then: handle action-specific audio
    switch (action) {
      case 'play_original':
        this.audioQueue.push({ type: 'original', entryId: actionData.entry_id })
        break

      case 'play_transcription':
        if (actionData.irish_text) {
          this.audioQueue.push({ type: 'irish', text: actionData.irish_text })
        }
        break

      case 'play_translation':
        if (actionData.english_text) {
          this.audioQueue.push({ type: 'english', text: actionData.english_text })
        }
        break

      case 'play_context':
        if (actionData.context_irish_text) {
          this.audioQueue.push({ type: 'irish', text: actionData.context_irish_text })
        }
        break
    }

    // Start playing the queue
    this.playNextInQueue()
  }

  handleResponse(event) {
    // Handler for Turbo Stream responses
    const { action, data, sessionState, currentEntryId } = event.detail

    this.sessionStateValue = sessionState
    if (currentEntryId) {
      this.currentEntryIdValue = currentEntryId
    }

    // Process action-specific audio
    this.audioQueue = []

    switch (action) {
      case 'play_original':
        this.audioQueue.push({ type: 'original', entryId: data.entry_id })
        break

      case 'play_transcription':
        if (data.irish_text) {
          this.audioQueue.push({ type: 'irish', text: data.irish_text })
        }
        break

      case 'play_translation':
        if (data.english_text) {
          this.audioQueue.push({ type: 'english', text: data.english_text })
        }
        break

      case 'play_context':
        if (data.context_irish_text) {
          this.audioQueue.push({ type: 'irish', text: data.context_irish_text })
        }
        break
    }

    if (this.audioQueue.length > 0) {
      this.playNextInQueue()
    }

    this.updateStatus('Tap to speak')
  }

  // Audio queue management
  playNextInQueue() {
    if (this.audioQueue.length === 0) {
      this.isPlayingAudio = false
      return
    }

    this.isPlayingAudio = true
    const item = this.audioQueue.shift()

    switch (item.type) {
      case 'english':
        this.speakEnglish(item.text, () => this.playNextInQueue())
        break
      case 'irish':
        this.speakIrishText(item.text, () => this.playNextInQueue())
        break
      case 'original':
        this.playOriginalAudio(item.entryId, () => this.playNextInQueue())
        break
    }
  }

  stopAllAudio() {
    this.audioQueue = []
    this.isPlayingAudio = false
    if (this.hasOriginalAudioTarget) {
      this.originalAudioTarget.pause()
    }
    if (this.hasTtsAudioTarget) {
      this.ttsAudioTarget.pause()
    }
  }

  // English TTS using browser speech synthesis
  speakEnglish(text, onComplete = null) {
    if (!text || !('speechSynthesis' in window)) {
      if (onComplete) onComplete()
      return
    }

    const utterance = new SpeechSynthesisUtterance(text)
    utterance.lang = 'en-US'
    utterance.rate = 0.9

    utterance.onend = () => {
      if (onComplete) onComplete()
    }

    utterance.onerror = () => {
      if (onComplete) onComplete()
    }

    speechSynthesis.speak(utterance)
  }

  // Irish TTS using Abair.ie via server
  async speakIrishText(text, onComplete = null) {
    if (!text) {
      if (onComplete) onComplete()
      return
    }

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
        const audio = new Audio(`data:audio/wav;base64,${data.audioContent}`)
        audio.onended = () => {
          if (onComplete) onComplete()
        }
        audio.onerror = () => {
          if (onComplete) onComplete()
        }
        audio.play()
      } else {
        if (onComplete) onComplete()
      }
    } catch (error) {
      console.error('Failed to speak Irish text:', error)
      if (onComplete) onComplete()
    }
  }

  // Play original audio segment
  async playOriginalAudio(entryId, onComplete = null) {
    try {
      const response = await fetch(`/mobile/voice/play_segment/${entryId}`, {
        headers: { 'Accept': 'application/json' }
      })
      const data = await response.json()

      if (data.audio_url && this.hasOriginalAudioTarget) {
        this.originalAudioTarget.src = data.audio_url
        this.originalAudioTarget.onended = () => {
          if (onComplete) onComplete()
        }
        this.originalAudioTarget.onerror = () => {
          if (onComplete) onComplete()
        }
        this.originalAudioTarget.play()
      } else {
        if (onComplete) onComplete()
      }
    } catch (error) {
      console.error('Failed to play original audio:', error)
      if (onComplete) onComplete()
    }
  }

  // Button handler for manual playback - uses data attribute from button
  playOriginal(event) {
    const entryId = event.currentTarget.dataset.entryId
    if (entryId) {
      this.stopAllAudio()
      this.playOriginalAudio(entryId)
    }
  }

  speakIrish() {
    const text = this.transcriptionTarget?.textContent?.trim()
    if (text) {
      this.stopAllAudio()
      this.speakIrishText(text)
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
    if (!content || !this.hasConversationTarget) return

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
