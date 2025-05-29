import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage";

export default class extends Controller {
  static targets = ["input", "synthesizeButton", "word", "media", "content"]
  static values = { url: String }

  connect() {
    console.info("connected to tts controller")
    // Find all Irish language spans and make them clickable for TTS
    this.element.querySelectorAll('span[lang="ga"]').forEach(span => {
      span.classList.add('cursor-pointer', 'hover:underline')
      span.setAttribute('title', 'Click to listen')
      span.addEventListener('click', (event) => this.speakIrish(event.target.textContent))
    })
  }

  async synthesizeAndUpload(event) {
    event.preventDefault();
    const text = this.wordTarget.value; // Get the text from your word_or_phrase input field
    const response = await this.synthesizeSpeech(text);
    const synthesizedAudioBase64 = response.audioContent;

    // Convert base64 audio data to a Blob
    const audioBlob = this.base64ToBlob(synthesizedAudioBase64, 'audio/ogg');
    const file = new File([audioBlob], 'audio.ogg', { type: 'audio/ogg' });

    // Direct upload to storage
    const upload = new DirectUpload(file, this.urlValue);
    upload.create((error, blob) => {
      if (error) {
        console.error(error)
      } else {
        this.createHiddenInput(blob.signed_id);
        setTimeout(() => {
          Turbo.navigator.submitForm(this.element.parentNode)
        }, 500); // Adjust the delay as needed
      }
    });
  }

  createHiddenInput(signedId) {
    const hiddenInput = document.createElement('input');
    hiddenInput.type = 'hidden';
    hiddenInput.name = this.inputTarget.name;
    hiddenInput.value = signedId;
    hiddenInput.setAttribute("data-target", "entry.media");
    this.inputTarget.parentNode.insertBefore(hiddenInput, this.inputTarget.nextSibling);
  }

  base64ToBlob(base64, mimeType) {
    const byteCharacters = atob(base64);
    const byteNumbers = new Array(byteCharacters.length);
    for (let i = 0; i < byteCharacters.length; i++) {
      byteNumbers[i] = byteCharacters.charCodeAt(i);
    }
    const byteArray = new Uint8Array(byteNumbers);
    return new Blob([byteArray], { type: mimeType });
  }

  async synthesizeSpeech(text) {
    try {
      const response = await fetch('/api/text_to_speech', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({ text: text })
      });

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      return await response.json();
    } catch (error) {
      console.error("TTS API error:", error);
      throw error;
    }
  }

  // Play TTS for any text with lang="ga" attribute
  playIrish(event) {
    const text = event.currentTarget.textContent
    this.speakIrish(text)
  }

  // Speak Irish text using the abair.ie API
  async speakIrish(text) {
    try {
      const response = await this.synthesizeSpeech(text)
      const synthesizedAudioBase64 = response.audioContent
      this.playSynthesizedAudio(synthesizedAudioBase64)
    } catch (error) {
      console.error("Error synthesizing speech:", error)
    }
  }

  playSynthesizedAudio(base64AudioData) {
    const audioContext = new AudioContext()
    const audioBuffer = this.base64ToArrayBuffer(base64AudioData)

    audioContext.decodeAudioData(audioBuffer, (buffer) => {
      const source = audioContext.createBufferSource()
      source.buffer = buffer
      source.connect(audioContext.destination)
      source.start(0)
    })
  }

  base64ToArrayBuffer(base64) {
    const binaryString = window.atob(base64)
    const bytes = new Uint8Array(binaryString.length)
    for (let i = 0; i < binaryString.length; i++) {
      bytes[i] = binaryString.charCodeAt(i)
    }
    return bytes.buffer
  }
}
