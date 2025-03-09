import { Controller } from "@hotwired/stimulus"
import WaveSurfer from "wavesurferjs"
import RegionsPlugin from 'wavesurferregionsjs';

export default class extends Controller {
  static targets = ["waveform", "playButton", "timeDisplay", "transcription", "translation", "gaeSubs", "engSubs", "speed", "video"]
  static values = {
    url: String,
    regionsUrl: String
  }

  connect() {
    if (!this.urlValue) return;
    this.initializeWaveform();
  }

  disconnect() {
    if (this.waveSurfer) {
      this.waveSurfer.destroy();
    }
  }

  initializeWaveform() {
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
      normalize: true,
      backend: 'MediaElement',
      mediaControls: false,
      plugins: [
        RegionsPlugin.create({
          dragSelection: false,
          regions: []
        })
      ]
    });

    // Load the appropriate media element
    const mediaElement = this.hasVideoTarget ? this.videoTarget : this.urlValue;
    this.waveSurfer.load(mediaElement);

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
      this.waveSurfer.zoom(200);

      // Fetch and add regions after waveform is ready
      if (this.hasRegionsUrlValue) {
        this.fetchAndAddRegions();
      }
    });

    this.waveSurfer.on('audioprocess', () => {
      if (this.waveSurfer.isPlaying()) {
        const currentTime = this.waveSurfer.getCurrentTime();
        timeDisplay.textContent = this.formatTime(currentTime);

        // Find and highlight the current entry
        this.highlightCurrentEntry(currentTime);
      }
    });

    this.waveSurfer.on('finish', () => {
      playButton.textContent = "Play";
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

      regions.forEach(region => {
        if (region.region_start != null && region.region_end != null) {
          this.waveSurfer.addRegion({
            start: parseFloat(region.region_start),
            end: parseFloat(region.region_end),
            drag: false,
            resize: false,
            color: 'rgba(79, 70, 229, 0.1)',
            data: {
              id: region.id,
              transcription: region.word_or_phrase,
              translation: region.translation
            }
          });
        }
      });
    } catch (error) {
      console.error('Error fetching regions:', error);
    }
  }

  play(event) {
    event.preventDefault();
    const button = event.currentTarget;

    if (!this.waveSurfer) return;

    this.waveSurfer.playPause();
    button.textContent = this.waveSurfer.isPlaying() ? "Pause" : "Play";
  }

  playRegion(event) {
    event.preventDefault();
    console.log("playRegion called");

    const audioUrl = event.currentTarget.dataset.audioUrl;
    console.log("Audio URL:", audioUrl);

    if (!audioUrl) {
      console.warn('No audio URL provided for this entry');
      return;
    }

    const transcription = event.currentTarget.dataset.transcription;
    const translation = event.currentTarget.dataset.translation;
    console.log("Playing snippet with transcription:", transcription);

    // Create a new audio element
    const audio = new Audio(audioUrl);

    // Add loading handler
    audio.addEventListener('loadstart', () => {
      console.log('Audio started loading');
    });

    // Add error handler
    audio.addEventListener('error', (e) => {
      console.error('Error loading audio:', e);
    });

    // Add play handler
    audio.addEventListener('play', () => {
      console.log('Audio started playing');
    });

    // Try to play the audio
    audio.play().catch(error => {
      console.error('Error playing audio:', error);
    });

    // Update subtitles if available
    if (this.hasTranscriptionTarget && this.hasTranslationTarget) {
      if (this.hasGaeSubsTarget && this.gaeSubsTarget.checked) {
        this.transcriptionTarget.textContent = transcription;
      }
      if (this.hasEngSubsTarget && this.engSubsTarget.checked) {
        this.translationTarget.textContent = translation;
      }

      // Reset subtitles when audio ends
      audio.addEventListener('ended', () => {
        console.log('Audio finished playing');
        this.transcriptionTarget.textContent = "~";
        this.translationTarget.textContent = "~";
      });
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
    console.log('Current time:', currentTime);

    // Remove highlight from all entries
    document.querySelectorAll('.bg-blue-50, .border-blue-500, .shadow-lg').forEach(el => {
      el.classList.remove('bg-blue-50', 'border-blue-500', 'border-2', 'shadow-lg', 'scale-[1.02]');
    });

    // Find the region that contains the current time
    const regions = this.waveSurfer.regions.list;
    console.log('Available regions:', Object.values(regions).map(r => ({
      start: r.start,
      end: r.end,
      id: r.data.id
    })));

    const currentRegion = Object.values(regions).find(region =>
      currentTime >= region.start && currentTime <= region.end
    );

    console.log('Found region:', currentRegion ? {
      start: currentRegion.start,
      end: currentRegion.end,
      id: currentRegion.data.id
    } : 'none');

    if (currentRegion && currentRegion.data.id) {
      // Find and highlight the corresponding dictionary entry
      const entryId = `dictionary_entry_${currentRegion.data.id}`;
      console.log('Looking for entry with ID:', entryId);

      const entryElement = document.getElementById(entryId);
      console.log('Found entry element:', entryElement ? 'yes' : 'no');

      if (entryElement) {
        // Add highlight with multiple effects
        entryElement.classList.add('bg-blue-50', 'border-blue-500', 'border-2', 'shadow-lg', 'scale-[1.02]');

        // Find the scrollable container - it's the flex-1 div with overflow-y-auto
        const container = document.querySelector('.flex-1.overflow-y-auto');
        console.log('Found scroll container:', container ? 'yes' : 'no');

        if (container) {
          const padding = 40; // Increased padding for better visibility

          // Get the element's position relative to the container
          const containerTop = container.scrollTop;
          const containerBottom = containerTop + container.clientHeight;
          const elementTop = entryElement.offsetTop;
          const elementBottom = elementTop + entryElement.offsetHeight;

          console.log('Scroll positions:', {
            containerTop,
            containerBottom,
            elementTop,
            elementBottom,
            containerHeight: container.clientHeight,
            elementHeight: entryElement.offsetHeight
          });

          // Check if the entry is fully visible with padding
          const isFullyVisible = (elementTop >= containerTop + padding) &&
                               (elementBottom <= containerBottom - padding);

          if (!isFullyVisible) {
            console.log('Entry not fully visible, scrolling...');

            // Calculate position to center the element
            const scrollPosition = elementTop - (container.clientHeight / 2) + (entryElement.offsetHeight / 2);

            // Ensure we don't scroll past the bounds
            const maxScroll = container.scrollHeight - container.clientHeight;
            const adjustedScrollPosition = Math.max(0, Math.min(scrollPosition, maxScroll));

            console.log('Scrolling to:', adjustedScrollPosition);

            container.scrollTo({
              top: adjustedScrollPosition,
              behavior: 'smooth'
            });
          } else {
            console.log('Entry fully visible');
          }
        }
      }
    }
  }
}