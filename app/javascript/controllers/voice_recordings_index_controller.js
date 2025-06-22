import { Controller } from "@hotwired/stimulus"
import WaveSurfer from "wavesurferjs"
import RegionsPlugin from 'wavesurferregionsjs';
import L from 'leaflet';

export default class extends Controller {
  static targets = ["map", "waveform", "playButton", "timeDisplay", "speed"]
  static values = {
    pins: Array,
    media: String
  }

  connect() {
    if (this.hasMapTarget) {
      this.initializeMap();
    }
    if (this.hasWaveformTarget) {
      this.initializeWaveform();
    }
  }

  disconnect() {
    if (this.waveSurfer) {
      this.waveSurfer.destroy();
    }
    if (this.map) {
      this.map.remove();
    }
  }

  initializeMap() {
    // Initialize the map
    this.map = L.map(this.mapTarget).setView([53.41291, -8.24389], 7);

    // Add the OpenStreetMap tiles
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '© OpenStreetMap contributors'
    }).addTo(this.map);

    // Add markers for each pin
    this.pinsValue.forEach(pin => {
      if (pin.lat_lang) {
        const [lat, lng] = pin.lat_lang.split(',').map(coord => parseFloat(coord.trim()));
        const marker = L.marker([lat, lng]).addTo(this.map);

        marker.bindPopup(`
          <div class="text-center">
            <h3 class="font-semibold">${pin.name}</h3>
            <p class="text-sm">${pin.recording_title}</p>
            <a href="/voice_recordings/${pin.recording_id}" class="text-blue-500 hover:text-blue-700">
              View Recording
            </a>
          </div>
        `);
      }
    });
  }

  initializeWaveform() {
    if (!this.mediaValue) return;

    const container = this.waveformTarget;
    const playButton = this.playButtonTarget;
    const timeDisplay = this.timeDisplayTarget;

    playButton.textContent = "Preparing wave...";

    this.waveSurfer = WaveSurfer.create({
      container: container,
      waveColor: '#4F46E5',
      progressColor: '#312E81',
      cursorColor: '#818CF8',
      barWidth: 2,
      barRadius: 3,
      cursorWidth: 1,
      height: 80,
      barGap: 3,
      responsive: true,
      normalize: true
    });

    this.waveSurfer.load(this.mediaValue);

    this.waveSurfer.on('loading', (progress) => {
      if (progress < 99) {
        playButton.textContent = `Loading ${progress}%`;
      } else {
        playButton.textContent = "Play";
      }
    });

    this.waveSurfer.on('ready', () => {
      playButton.textContent = "Play";
      playButton.disabled = false;
    });

    this.waveSurfer.on('audioprocess', () => {
      if (this.waveSurfer.isPlaying()) {
        timeDisplay.textContent = this.formatTime(this.waveSurfer.getCurrentTime());
      }
    });

    this.waveSurfer.on('finish', () => {
      playButton.textContent = "Play";
    });
  }

  play(event) {
    event.preventDefault();
    const button = event.currentTarget;

    if (!this.waveSurfer) return;

    this.waveSurfer.playPause();
    button.textContent = this.waveSurfer.isPlaying() ? "Pause" : "Play";
  }

  changeSpeed(event) {
    event.preventDefault();
    if (!this.waveSurfer) return;

    const speed = parseFloat(event.currentTarget.value);
    this.waveSurfer.setPlaybackRate(speed);
  }

  formatTime(seconds) {
    seconds = Math.floor(seconds);
    let minutes = Math.floor(seconds / 60);
    seconds = seconds % 60;
    return `${minutes}:${seconds.toString().padStart(2, '0')}`;
  }
}