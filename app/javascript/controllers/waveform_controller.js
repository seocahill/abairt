import { Controller } from "@hotwired/stimulus"
import WaveSurfer from "wavesurferjs"
import RegionsPlugin from 'wavesurferregionsjs';

export default class extends Controller {
  static targets = ["waveform", "playButton", "timeDisplay", "transcription", "translation", "gaeSubs", "engSubs", "speed", "video", "editButton"]
  static values = {
    url: String,
    regionsUrl: String,
    lazy: Boolean,
    editMode: Boolean,
    entryUpdateUrlTemplate: String
  }

  connect() {
    // Only initialize if waveform target exists (media is attached)
    if (!this.hasWaveformTarget) {
      return; // Exit early if no waveform target exists
    }
    
    if (!this.lazyValue) {
      this.initializeWaveform();
    } else {
      this.showDummyWaveform();
    }
  }

  disconnect() {
    if (this.waveSurfer) {
      this.waveSurfer.destroy();
    }
  }

  showDummyWaveform() {
    const container = this.waveformTarget;
    
    // Don't show if placeholder already exists
    if (document.getElementById('waveform-placeholder')) {
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
    placeholder.id = 'waveform-placeholder';
    placeholder.style.cssText = 'position: absolute; top: 0; left: 0; right: 0; bottom: 0; z-index: 10; pointer-events: none; background: white;';
    
    // Create SVG for dummy waveform
    const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    svg.setAttribute("width", width);
    svg.setAttribute("height", height);
    svg.setAttribute("viewBox", `0 0 ${width} ${height}`);
    svg.style.cssText = "display: block; width: 100%; height: 100%; background: transparent;";
    
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
    
    placeholder.appendChild(svg);
    container.appendChild(placeholder);
  }

  removePlaceholder() {
    const placeholder = document.getElementById('waveform-placeholder');
    if (placeholder) {
      placeholder.remove();
    }
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
      this.playButtonTarget.disabled = true;
    }

    try {
      const container = this.waveformTarget;
      // Show placeholder waveform
      this.showDummyWaveform();

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

      // Load the media with streaming support
      if (this.hasVideoTarget) {
        await this.waveSurfer.load(this.videoTarget);
      } else {
        // Create audio element with metadata preload for streaming
        const audio = document.createElement('audio');
        audio.preload = 'metadata';  // Only load metadata initially
        audio.crossOrigin = 'anonymous';
        audio.src = this.urlValue;
        
        // Set up audio element for streaming
        audio.addEventListener('loadedmetadata', () => {
          // Metadata loaded, can start playing (streaming will happen on play)
          if (this.hasPlayButtonTarget) {
            this.playButtonTarget.disabled = false;
          }
        });

        audio.addEventListener('error', (e) => {
          console.error('Audio loading error:', e);
          if (this.hasPlayButtonTarget) {
            this.playButtonTarget.disabled = true;
          }
        });

        // Load the audio element (not URL) for streaming support
        await this.waveSurfer.load(audio);
      }

      // Fetch and add regions
      if (this.hasRegionsUrlValue) {
        await this.fetchAndAddRegions();
      }

      this.waveSurfer.zoom(10);
      if (this.hasPlayButtonTarget) {
        this.playButtonTarget.disabled = false;
      }
    } catch (error) {
      console.error('Error initializing waveform:', error);
      if (this.hasPlayButtonTarget) {
        this.playButtonTarget.disabled = true;
      }
      throw error;
    }
  }

  setupWaveformEventListeners() {
    this.waveSurfer.on('ready', () => {
      if (this.hasPlayButtonTarget) {
        this.playButtonTarget.disabled = false;
      }
      
      // Set up pitch preservation on the underlying media element
      this.setupPitchPreservation();
      
      // Remove placeholder after a brief delay to ensure waveform is visible
      setTimeout(() => {
        this.removePlaceholder();
      }, 100);
      
      // Auto-play if requested
      if (this.shouldAutoPlay) {
        this.shouldAutoPlay = false;
        this.waveSurfer.play();
      }
    });

    this.waveSurfer.on('play', () => {
      this.updatePlayButtonState(true);
    });

    this.waveSurfer.on('pause', () => {
      this.updatePlayButtonState(false);
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
      this.updatePlayButtonState(false);
    });

    // Update subtitle highlighting when seeking
    this.waveSurfer.on('seek', () => {
      const currentTime = this.waveSurfer.getCurrentTime();
      if (this.hasTimeDisplayTarget) {
        this.timeDisplayTarget.textContent = this.formatTime(currentTime);
      }
      this.highlightCurrentEntry(currentTime);
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
      this._regionsData = regions;

      this._renderRegions();
    } catch (error) {
      console.error('Error fetching regions:', error);
    }
  }

  _renderRegions() {
    if (!this.waveSurfer || !this._regionsData) return;

    // Clear existing regions
    this.waveSurfer.clearRegions();

    const editable = this.editModeValue;

    this._regionsData.forEach(region => {
      if (region.region_start != null && region.region_end != null) {
        this.waveSurfer.addRegion({
          start: parseFloat(region.region_start),
          end: parseFloat(region.region_end),
          drag: editable,
          resize: editable,
          color: editable ? 'rgba(234, 179, 8, 0.2)' : 'rgba(79, 70, 229, 0.1)',
          data: {
            id: region.id,
            transcription: region.word_or_phrase,
            translation: region.translation
          }
        });
      }
    });

    if (editable) {
      this._setupRegionUpdateListener();
    }
  }

  _setupRegionUpdateListener() {
    // Remove any previous listener to avoid duplicates
    if (this._regionUpdateHandler) {
      this.waveSurfer.un('region-update-end', this._regionUpdateHandler);
    }

    this._regionUpdateHandler = async (region) => {
      const entryId = region.data?.id;
      if (!entryId || !this.hasEntryUpdateUrlTemplateValue) return;

      const url = this.entryUpdateUrlTemplateValue.replace('ENTRY_ID', entryId);
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content;

      try {
        const response = await fetch(url, {
          method: 'PATCH',
          headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': csrfToken,
            'Accept': 'application/json'
          },
          body: JSON.stringify({
            dictionary_entry: {
              region_start: region.start.toFixed(3),
              region_end: region.end.toFixed(3)
            }
          })
        });

        if (!response.ok) {
          console.error('Failed to update segment boundary:', await response.text());
        }
      } catch (error) {
        console.error('Error patching segment boundary:', error);
      }
    };

    this.waveSurfer.on('region-update-end', this._regionUpdateHandler);
  }

  toggleEditMode() {
    this.editModeValue = !this.editModeValue;
    this._renderRegions();

    if (this.hasEditButtonTarget) {
      if (this.editModeValue) {
        this.editButtonTarget.classList.remove('text-gray-400', 'hover:text-gray-600');
        this.editButtonTarget.classList.add('text-yellow-500', 'hover:text-yellow-600');
        this.editButtonTarget.title = 'Exit segment edit mode';
      } else {
        this.editButtonTarget.classList.remove('text-yellow-500', 'hover:text-yellow-600');
        this.editButtonTarget.classList.add('text-gray-400', 'hover:text-gray-600');
        this.editButtonTarget.title = 'Edit segment boundaries';
      }
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
      this.findAndHighlightEntry(currentRegion.data.id);
    }
  }

  async findAndHighlightEntry(entryId) {
    const entryElementId = `dictionary_entry_${entryId}`;
    console.log('Looking for entry with ID:', entryElementId);

    let entryElement = document.getElementById(entryElementId);
    
    // If entry is not in DOM, try to load more entries
    if (!entryElement) {
      console.log('Entry not found in DOM, attempting to load more entries...');
      
      const success = await this.loadEntryIfNeeded(entryId);
      if (success) {
        entryElement = document.getElementById(entryElementId);
      }
    }

    if (entryElement) {
      console.log('Found entry element, highlighting...');
      this.highlightAndScrollToEntry(entryElement);
    } else {
      console.log('Entry element not found even after attempting to load more entries');
    }
  }

  async loadEntryIfNeeded(entryId) {
    // Find the infinite scroll controller
    const infiniteScrollElement = document.querySelector('[data-controller*="infinite-scroll"]');
    if (!infiniteScrollElement) {
      console.log('Infinite scroll controller not found');
      return false;
    }

    const infiniteScrollController = this.application.getControllerForElementAndIdentifier(
      infiniteScrollElement, 
      'infinite-scroll'
    );
    
    if (!infiniteScrollController) {
      console.log('Could not get infinite scroll controller instance');
      return false;
    }

    // Keep loading pages until we find the entry or run out of pages
    let attempts = 0;
    const maxAttempts = 10; // Prevent infinite loops
    
    while (attempts < maxAttempts) {
      // Check if there's a next page available
      const nextPageLink = document.querySelector("a[rel='next']");
      if (!nextPageLink) {
        console.log('No more pages available');
        return false;
      }

      console.log(`Attempt ${attempts + 1}: Loading more entries...`);
      
      // Trigger loading more entries
      await infiniteScrollController.loadMore();
      
      // Wait a bit for the DOM to update
      await new Promise(resolve => setTimeout(resolve, 300));
      
      // Check if our target entry is now in the DOM
      const entryElement = document.getElementById(`dictionary_entry_${entryId}`);
      if (entryElement) {
        console.log('Target entry found after loading more entries');
        return true;
      }
      
      attempts++;
    }
    
    console.log('Failed to find entry after maximum attempts');
    return false;
  }

  highlightAndScrollToEntry(entryElement) {
    // Add highlight with multiple effects
    entryElement.classList.add('bg-blue-50', 'border-blue-500', 'border-2', 'shadow-lg', 'scale-[1.02]');

    // Use scrollIntoView with block: 'start' to position element at top of scroll container
    // The scroll-mt-20 class on the entry will provide the spacing
    console.log('Scrolling entry into view:', entryElement.id);

    entryElement.scrollIntoView({
      behavior: 'smooth',
      block: 'start'
    });
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
}