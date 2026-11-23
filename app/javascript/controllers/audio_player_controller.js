import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["speed"]
  static values = {
    url: String,
    transcription: String,
    translation: String,
    // Optional: play only this stretch of a longer recording (in seconds).
    start: Number,
    end: Number
  }

  get clipped() {
    return this.endValue > this.startValue
  }

  // The clip is only created, and so only downloaded, on the first tap.
  ensureAudio() {
    if (this.audio || !this.urlValue) return this.audio;

    this.audio = new Audio();
    this.audio.preload = "none";
    this.audio.src = this.urlValue;

    // Set preservesPitch for audio playback with cross-browser support
    this.audio.preservesPitch = true;
    this.audio.mozPreservesPitch = true;
    this.audio.webkitPreservesPitch = true;
    if (this.playbackRate) this.audio.playbackRate = this.playbackRate;
    if (this.clipped) this.audio.addEventListener('timeupdate', () => this.stopAtEnd());
    return this.audio;
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

    if (!this.ensureAudio()) {
      console.warn('No audio URL provided');
      return;
    }

    if (this.audio.paused) {
      this.button = button;
      if (this.clipped && (this.audio.currentTime < this.startValue || this.audio.currentTime >= this.endValue)) {
        this.audio.currentTime = this.startValue;
      }
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

  stopAtEnd() {
    // The line may have been replaced (and this controller disconnected) mid-clip.
    if (!this.audio || this.audio.paused || this.audio.currentTime < this.endValue) return;

    this.audio.pause();
    this.button?.classList.remove('text-blue-800', 'bg-blue-200');
  }

  changeSpeed(event) {
    event.preventDefault();
    const speed = parseFloat(event.currentTarget.value);
    this.playbackRate = speed;
    if (this.audio) this.audio.playbackRate = speed;
  }
}