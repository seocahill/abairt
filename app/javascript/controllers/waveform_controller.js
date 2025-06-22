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
    } else {
      this.showDummyWaveform();
      if (this.hasPlayButtonTarget) {
        this.playButtonTarget.textContent = "Play";
      }
    }
  }

  disconnect() {
    if (this.waveSurfer) {
      this.waveSurfer.destroy();
    }
  }

  showDummyWaveform() {
    const container = this.waveformTarget;
    const width = container.offsetWidth || 800;
    const height = 80;
    
    // Create SVG for dummy waveform
    const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    svg.setAttribute("width", width);
    svg.setAttribute("height", height);
    svg.setAttribute("viewBox", `0 0 ${width} ${height}`);
    svg.style.cssText = "display: block; width: 100%; background: transparent;";
    
    // Generate random waveform bars
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
      rect.setAttribute("fill", "#E5E7EB"); // Gray color for dummy waveform
      
      svg.appendChild(rect);
    }
    
    container.innerHTML = '';
    container.appendChild(svg);
  }

  async play() {
    if (!this.waveSurfer) {
      this.shouldAutoPlay = true;
      await this.initializeWaveform();
    } else {
      this.waveSurfer.playPause();
    }
  }

  async initializeWaveform() {
    if (this.hasPlayButtonTarget) {
      this.playButtonTarget.textContent = "Loading...";
      this.playButtonTarget.disabled = true;
    }

    try {
      const container = this.waveformTarget;
      // Clear the container (removes dummy waveform)
      container.innerHTML = '';

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
      
      // Set up pitch preservation on the underlying media element
      this.setupPitchPreservation();
      
      // Auto-play if requested
      if (this.shouldAutoPlay) {
        this.shouldAutoPlay = false;
        this.waveSurfer.play();
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
          this.transcriptionTarget.textContent = "";
        }
        if (this.hasTranslationTarget) {
          this.translationTarget.textContent = "";
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

  setupPitchPreservation() {
    // Access the underlying media element for MediaElement backend
    if (this.waveSurfer.backend && this.waveSurfer.backend.media) {
      const mediaElement = this.waveSurfer.backend.media;
      mediaElement.preservesPitch = true;
      mediaElement.mozPreservesPitch = true;
      mediaElement.webkitPreservesPitch = true;
    }
  }

  changeSpeed(event) {
    event.preventDefault();
    if (!this.waveSurfer) return;

    const speed = parseFloat(event.currentTarget.value);
    
    // Use the underlying media element for pitch preservation
    if (this.waveSurfer.backend && this.waveSurfer.backend.media) {
      const mediaElement = this.waveSurfer.backend.media;
      mediaElement.playbackRate = speed;
    } else {
      // Fallback to WaveSurfer method
      this.waveSurfer.setPlaybackRate(speed);
    }
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