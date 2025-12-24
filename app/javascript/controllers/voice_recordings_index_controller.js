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

    // Show placeholder waveform
    this.showPlaceholderWaveform(container);

    // Create audio element with metadata preload for streaming support
    const audio = document.createElement('audio');
    audio.preload = 'metadata';  // Only load metadata initially, not full file
    audio.crossOrigin = 'anonymous';
    audio.src = this.mediaValue;

    // Set up audio element event listeners
    audio.addEventListener('loadedmetadata', () => {
      // Metadata loaded, can start playing (streaming will happen on play)
      if (playButton) {
        playButton.disabled = false;
      }
    });

    audio.addEventListener('error', (e) => {
      console.error('Audio loading error:', e);
      if (playButton) {
        playButton.disabled = true;
      }
    });

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
      normalize: true,
      backend: 'MediaElement',  // Use MediaElement backend for streaming support
      mediaControls: false,
      // Configure XHR for range requests
      xhr: {
        withCredentials: false,
        mode: 'cors'
      }
    });

    // Load the audio element (not URL) for streaming support
    this.waveSurfer.load(audio);

    this.waveSurfer.on('ready', () => {
      playButton.disabled = false;
      
      // Remove placeholder after a brief delay to ensure waveform is visible
      setTimeout(() => {
        this.removePlaceholder();
      }, 100);
    });

    this.waveSurfer.on('play', () => {
      this.updatePlayButtonState(true);
    });

    this.waveSurfer.on('pause', () => {
      this.updatePlayButtonState(false);
    });

    this.waveSurfer.on('finish', () => {
      this.updatePlayButtonState(false);
    });

    this.waveSurfer.on('audioprocess', () => {
      if (this.waveSurfer.isPlaying()) {
        timeDisplay.textContent = this.formatTime(this.waveSurfer.getCurrentTime());
      }
    });
  }

  showPlaceholderWaveform(container) {
    // Don't show if placeholder already exists
    if (document.getElementById('waveform-placeholder-index')) {
      return;
    }
    
    const width = container.offsetWidth || 800;
    const height = 80;
    
    // Ensure container has fixed height to prevent layout shift
    if (!container.style.height) {
      container.style.height = `${height}px`;
    }
    if (!container.style.position) {
      container.style.position = 'relative';
    }
    
    // Create placeholder wrapper
    const placeholder = document.createElement('div');
    placeholder.id = 'waveform-placeholder-index';
    placeholder.style.cssText = 'position: absolute; top: 0; left: 0; right: 0; bottom: 0; z-index: 10; pointer-events: none; background: white;';
    
    // Create SVG for placeholder waveform
    const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    svg.setAttribute("width", width);
    svg.setAttribute("height", height);
    svg.setAttribute("viewBox", `0 0 ${width} ${height}`);
    svg.style.cssText = "display: block; width: 100%; height: 100%; background: transparent;";
    
    // Generate placeholder waveform bars
    const barWidth = 2;
    const barGap = 3;
    const totalBarWidth = barWidth + barGap;
    const barCount = Math.floor(width / totalBarWidth);
    
    for (let i = 0; i < barCount; i++) {
      const barHeight = Math.random() * (height - 20) + 10; // Random height between 10 and height-10
      const x = i * totalBarWidth;
      const y = (height - barHeight) / 2;
      
      const rect = document.createElementNS("http://www.w3.org/2000/svg", "rect");
      rect.setAttribute("x", x);
      rect.setAttribute("y", y);
      rect.setAttribute("width", barWidth);
      rect.setAttribute("height", barHeight);
      rect.setAttribute("rx", "3");
      rect.setAttribute("fill", "#E5E7EB"); // Gray color for placeholder waveform
      
      svg.appendChild(rect);
    }
    
    placeholder.appendChild(svg);
    container.appendChild(placeholder);
  }

  removePlaceholder() {
    const placeholder = document.getElementById('waveform-placeholder-index');
    if (placeholder) {
      placeholder.remove();
    }
  }

  play(event) {
    event.preventDefault();

    if (!this.waveSurfer) return;

    this.waveSurfer.playPause();
    this.updatePlayButtonState(this.waveSurfer.isPlaying());
  }

  updatePlayButtonState(isPlaying) {
    if (!this.hasPlayButtonTarget) return;

    const button = this.playButtonTarget;
    const svg = button.querySelector('svg');
    const span = button.querySelector('span');

    if (isPlaying) {
      // Update to pause icon
      if (svg) {
        svg.innerHTML = '<path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zM7 8a1 1 0 012 0v4a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v4a1 1 0 102 0V8a1 1 0 00-1-1z" clip-rule="evenodd" />';
      }
      if (span) {
        span.textContent = 'Pause';
      } else if (!svg) {
        // Fallback if no SVG or span, just update text
        button.textContent = 'Pause';
      }
      button.setAttribute('aria-label', 'Pause');
    } else {
      // Update to play icon
      if (svg) {
        svg.innerHTML = '<path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z" clip-rule="evenodd" />';
      }
      if (span) {
        span.textContent = 'Play';
      } else if (!svg) {
        // Fallback if no SVG or span, just update text
        button.textContent = 'Play';
      }
      button.setAttribute('aria-label', 'Play');
    }
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