import { Controller } from "@hotwired/stimulus"
import WaveSurfer from "wavesurferjs"
import RegionsPlugin from 'wavesurferregionsjs';

export default class extends Controller {
  static targets = ["waveform", "playButton", "timeDisplay", "transcription", "translation", "gaeSubs", "engSubs", "speed", "video"]
  static values = {
    url: String,
    regionsUrl: String,
    lazy: Boolean
  }

  connect() {
    if (!this.lazyValue) {
      this.initializeWaveform();
    } else if (this.hasPlayButtonTarget) {
      this.playButtonTarget.textContent = "Play";
    }
  }

  disconnect() {
    if (this.waveSurfer) {
      this.waveSurfer.destroy();
    }
  }

  async play() {
    if (!this.waveSurfer) {
      await this.initializeWaveform();
    }
    this.waveSurfer.playPause();
  }

  async initializeWaveform() {
    if (this.hasPlayButtonTarget) {
      this.playButtonTarget.textContent = "Loading...";
      this.playButtonTarget.disabled = true;
    }

    try {
      const container = this.waveformTarget;

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
        backend: this.hasVideoTarget ? 'MediaElement' : 'WebAudio',
        mediaControls: false,
        plugins: [
          RegionsPlugin.create({
            dragSelection: false,
            regions: []
          })
        ]
      });

      // Set up event listeners
      this.setupWaveformEventListeners();

      // Load the media
      if (this.hasVideoTarget) {
        await this.waveSurfer.load(this.videoTarget);
      } else {
        await this.waveSurfer.load(this.urlValue);
      }

      // Fetch and add regions
      if (this.hasRegionsUrlValue) {
        await this.fetchAndAddRegions();
      }

      this.waveSurfer.zoom(200);
      if (this.hasPlayButtonTarget) {
        this.playButtonTarget.disabled = false;
      }
    } catch (error) {
      console.error('Error initializing waveform:', error);
      if (this.hasPlayButtonTarget) {
        this.playButtonTarget.textContent = "Error";
        this.playButtonTarget.disabled = true;
      }
      throw error;
    }
  }

  setupWaveformEventListeners() {
    this.waveSurfer.on('loading', (progress) => {
      if (this.hasPlayButtonTarget) {
        if (progress < 99) {
          this.playButtonTarget.textContent = `Loading ${progress}%`;
        } else {
          this.playButtonTarget.textContent = "Play";
        }
      }
    });

    this.waveSurfer.on('ready', () => {
      if (this.hasPlayButtonTarget) {
        this.playButtonTarget.textContent = "Play";
        this.playButtonTarget.disabled = false;
      }
    });

    this.waveSurfer.on('play', () => {
      if (this.hasPlayButtonTarget) {
        this.playButtonTarget.textContent = "Pause";
      }
    });

    this.waveSurfer.on('pause', () => {
      if (this.hasPlayButtonTarget) {
        this.playButtonTarget.textContent = "Play";
      }
    });

    this.waveSurfer.on('audioprocess', () => {
      if (this.waveSurfer.isPlaying()) {
        const currentTime = this.waveSurfer.getCurrentTime();
        if (this.hasTimeDisplayTarget) {
          this.timeDisplayTarget.textContent = this.formatTime(currentTime);
        }
        this.highlightCurrentEntry(currentTime);
      }
    });

    this.waveSurfer.on('finish', () => {
      if (this.hasPlayButtonTarget) {
        this.playButtonTarget.textContent = "Play";
      }
    });

    // Handle subtitles
    if (this.hasTranscriptionTarget && this.hasTranslationTarget) {
      this.waveSurfer.on('region-in', (region) => {
        if (this.hasGaeSubsTarget && this.gaeSubsTarget.checked) {
          this.transcriptionTarget.textContent = region.data.transcription;
        }
        if (this.hasEngSubsTarget && this.engSubsTarget.checked) {
          this.translationTarget.textContent = region.data.translation;
        }
      });

      this.waveSurfer.on('region-out', () => {
        if (this.hasTranscriptionTarget) {
          this.transcriptionTarget.textContent = "~";
        }
        if (this.hasTranslationTarget) {
          this.translationTarget.textContent = "~";
        }
      });
    }
  }

  async fetchAndAddRegions() {
    try {
      const response = await fetch(this.regionsUrlValue);
      if (!response.ok) throw new Error('Failed to fetch regions');
      const regions = await response.json();

      regions.forEach((region) => {
        this.waveSurfer.addRegion({
          id: region.region_id,
          start: region.region_start,
          end: region.region_end,
          drag: false,
          data: { entry_id: region.id }
        });
      });
    } catch (error) {
      console.error('Error fetching regions:', error);
    }
  }

  changeSpeed(event) {
    event.preventDefault();
    if (!this.waveSurfer) return;

    const speed = parseFloat(event.currentTarget.value);
    this.waveSurfer.setPlaybackRate(speed);
  }

  zoom(event) {
    event.preventDefault();
    if (!this.waveSurfer) return;

    const zoomLevel = Number(event.currentTarget.value);
    this.waveSurfer.zoom(zoomLevel);
  }

  formatTime(seconds) {
    seconds = Math.floor(seconds);
    let minutes = Math.floor(seconds / 60);
    seconds = seconds % 60;
    return `${minutes}:${seconds.toString().padStart(2, '0')}`;
  }

  highlightCurrentEntry(currentTime) {
    if (!this.hasTranscriptionTarget || !this.hasTranslationTarget) return;

    const currentRegion = Object.values(this.waveSurfer.regions.list).find(region => {
      return currentTime >= region.start && currentTime <= region.end;
    });

    if (currentRegion) {
      if (this.hasGaeSubsTarget && this.gaeSubsTarget.checked) {
        this.transcriptionTarget.textContent = currentRegion.data.transcription || '~';
      }
      if (this.hasEngSubsTarget && this.engSubsTarget.checked) {
        this.translationTarget.textContent = currentRegion.data.translation || '~';
      }
    } else {
      this.transcriptionTarget.textContent = '~';
      this.translationTarget.textContent = '~';
    }
  }
}