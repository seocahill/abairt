import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["video", "speed"]
  static values = {
    url: String
  }

  connect() {
    if (this.hasVideoTarget) {
      // Set preservesPitch for video playback
      this.videoTarget.preservesPitch = true;
      this.videoTarget.mozPreservesPitch = true;
      this.videoTarget.webkitPreservesPitch = true;

      this.video = this.videoTarget
      this.enableCaptions()

      this.videoTarget.addEventListener('loadedmetadata', () => {
        // Video metadata is loaded and ready
        console.log("Video loaded:", this.urlValue)
      })
    }
  }

  disconnect() {
    if (this.hasVideoTarget) {
      // Clean up any event listeners or resources
      this.videoTarget.pause()
    }
  }

  enableCaptions() {
    // Wait for tracks to load
    this.video.addEventListener('loadedmetadata', () => {
      // Enable Irish subtitles by default
      for (const track of this.video.textTracks) {
        if (track.language === 'ga') {
          track.mode = 'showing'
        } else {
          track.mode = 'hidden'
        }
      }
    })
  }

  changeSpeed(event) {
    event.preventDefault();
    if (!this.hasVideoTarget) return;

    const speed = parseFloat(event.currentTarget.value);
    this.videoTarget.playbackRate = speed;
  }
}