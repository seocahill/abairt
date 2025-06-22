import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    originalUrl: String,
    practiceUrl: String
  }

  connect() {
    if (this.originalUrlValue && this.practiceUrlValue) {
      this.originalAudio = new Audio(this.originalUrlValue);
      this.practiceAudio = new Audio(this.practiceUrlValue);
      
      // Preload both audio files
      this.originalAudio.preload = "auto";
      this.practiceAudio.preload = "auto";
    }
  }

  disconnect() {
    if (this.originalAudio) {
      this.originalAudio.pause();
      this.originalAudio = null;
    }
    if (this.practiceAudio) {
      this.practiceAudio.pause();
      this.practiceAudio = null;
    }
  }

  playBoth(event) {
    event.preventDefault();
    const button = event.currentTarget;

    if (!this.originalAudio || !this.practiceAudio) {
      console.warn('Audio URLs not provided');
      return;
    }

    // Reset both audio elements to the beginning
    this.originalAudio.currentTime = 0;
    this.practiceAudio.currentTime = 0;

    // Play both audio files
    Promise.all([
      this.originalAudio.play(),
      this.practiceAudio.play()
    ]).catch(error => {
      console.error('Error playing audio:', error);
      button.classList.remove('text-purple-800', 'bg-purple-200');
    });

    // Add visual feedback
    button.classList.add('text-purple-800', 'bg-purple-200');

    // Add ended handlers to reset button state
    const resetButton = () => {
      button.classList.remove('text-purple-800', 'bg-purple-200');
    };

    this.originalAudio.addEventListener('ended', resetButton, { once: true });
    this.practiceAudio.addEventListener('ended', resetButton, { once: true });
  }
} 