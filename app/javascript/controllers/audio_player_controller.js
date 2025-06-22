import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["speed"]
  static values = {
    url: String,
    transcription: String,
    translation: String
  }

  connect() {
    if (this.urlValue) {
      this.audio = new Audio();
      this.audio.preload = "auto";
      this.audio.src = this.urlValue;
      
      // Set preservesPitch for audio playback with cross-browser support
      this.audio.preservesPitch = true;
      this.audio.mozPreservesPitch = true;
      this.audio.webkitPreservesPitch = true;
    }
  }

  disconnect() {
    if (this.audio) {
      this.audio.pause();
      this.audio = null;
    }
  }

  play(event) {
    event.preventDefault();
    const button = event.currentTarget;

    if (!this.audio) {
      console.warn('No audio URL provided');
      return;
    }

    if (this.audio.paused) {
      button.classList.add('text-blue-800', 'bg-blue-200');
      this.audio.play().catch(error => {
        console.error('Error playing audio:', error);
        button.classList.remove('text-blue-800', 'bg-blue-200');
      });
    } else {
      button.classList.remove('text-blue-800', 'bg-blue-200');
      this.audio.pause();
    }

    // Add ended handler to reset button state
    this.audio.addEventListener('ended', () => {
      button.classList.remove('text-blue-800', 'bg-blue-200');
    }, { once: true }); // Use once: true to automatically remove the listener after it fires
  }

  changeSpeed(event) {
    event.preventDefault();
    if (!this.audio) return;

    const speed = parseFloat(event.currentTarget.value);
    this.audio.playbackRate = speed;
  }
}