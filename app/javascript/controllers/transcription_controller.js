import { Controller } from "@hotwired/stimulus"
import WaveSurfer from "wavesurferjs"
import RegionsPlugin from 'wavesurferregionsjs';

export default class extends Controller {
  static targets = ["time", "waveform"]
  static values = {
    media: String,
    regionsUrl: String
  }

  connect() {
    this.element[this.identifier] = this
    document.addEventListener('keydown', this.handleKeyDown.bind(this));
    
    // Listen for seek events from entry controllers
    this.element.addEventListener('waveform:seek', this.handleSeekEvent.bind(this));
  }

  disconnect() {
    document.removeEventListener('keydown', this.handleKeyDown.bind(this));
    this.element.removeEventListener('waveform:seek', this.handleSeekEvent.bind(this));
  }

  initialize() {
    addEventListener("turbo:submit-end", ({ target }) => {
      console.log("RESET!")
      this.resetForm(target)
      if (target.action.includes("add_region")) {
        this.addRegionAtCurrent()
      }
    })
  }

  waveformTargetConnected() {
    let playButton = this.element.querySelector('#play-pause-button');
    playButton.innerHTML = "Preparing wave....";
    let that = this;
    this.waveSurfer = WaveSurfer.create({
      backend: 'MediaElement',
      container: '#waveform',
      waveColor: 'violet',
      progressColor: 'purple',
      partialRender: false,
      pixelRatio: 1,
      scrollParent: true,
      plugins: [
        RegionsPlugin.create({
          dragSelection: true,
        })
      ]
    })
    this.waveSurfer.load(this.mediaValue);

    this.waveSurfer.on('loading', function (progress) {
      playButton.classList.remove("cursor-not-allowed");
      // Don't show loading text, just keep placeholder
    })

    this.waveSurfer.on('ready', async function() {
      that.toggleButton();

      // Fetch and add regions from the URL
      if (that.hasRegionsUrlValue) {
        try {
          const response = await fetch(that.regionsUrlValue);
          if (!response.ok) throw new Error('Failed to fetch regions');
          const regions = await response.json();

          regions.forEach((region) => {
            that.waveSurfer.addRegion({
              id: region.region_id,
              start: region.region_start,
              end: region.region_end,
              drag: false,
              data: {
                entry_id: region.id
              }
            });
          });
        } catch (error) {
          console.error('Error fetching regions:', error);
        }
      }
    })

    this.waveSurfer.on('play', function() {
      that.toggleButton();
    })

    this.waveSurfer.on('pause', function() {
      that.toggleButton();
    })

    this.waveSurfer.on('finish', function() {
      that.toggleButton();
    })

    this.waveSurfer.on('audioprocess', function () {
      if (that.waveSurfer.isPlaying() && that.hasTimeTarget) {
        that.timeTarget.innerText = that.formatTime(that.waveSurfer.getCurrentTime().toFixed(1))
        if (document.getElementById('current-position')) {
          document.getElementById('current-position').value = that.waveSurfer.getCurrentTime().toFixed(2);
        }
      }
    })

    this.waveSurfer.on('seek', function() {
      if (that.hasTimeTarget) {
        that.timeTarget.innerText = that.waveSurfer.getCurrentTime().toFixed(1)
      }
      if (document.getElementById('current-position')) {
        document.getElementById('current-position').value = that.waveSurfer.getCurrentTime().toFixed(1);
      }
    })

    this.waveSurfer.on('region-created', function (region) {
      // Fill the hidden form fields with the new region's data
      document.getElementById('prev-position').value = Math.round(region.start * 10) / 10;
      document.getElementById('current-position').value = Math.round(region.end * 10) / 10;
      document.getElementById('dictionary_entry_region_id').value = region.id;
      
      // Show save button for new unsaved region
      that.showSaveButton(region);
    });

    this.waveSurfer.on('region-click', function (region, e) {
      e.stopPropagation();
      // Play on click, loop on shift click
      if (e.altKey) {
        if (!confirm('Are you sure you want to delete this region? This action cannot be undone.')) {
          console.log('Region deletion cancelled.');
          return;
        }
        region.remove();
      } else {
        region.play();
      }
    })

    this.waveSurfer.on('region-update-end', function (region) {
      // Update the form fields
      document.getElementById('prev-position').value = Math.round(region.start * 10) / 10;
      document.getElementById('current-position').value = Math.round(region.end * 10) / 10;
      document.getElementById('dictionary_entry_region_id').value = region.id;

      // Only proceed with AJAX update if the region is already persisted
      if (!region.data.entry_id) {
        console.log('Region updated but not yet persisted');
        return;
      }

      // Get CSRF token from meta tag
      const csrfToken = document.querySelector('meta[name="csrf-token"]').getAttribute('content');

      // Prepare the data to be sent
      const updateData = {
        dictionary_entry: {
          region_start: region.start,
          region_end: region.end
        }
      };

      // Send the data to the backend using fetch API
      fetch(`/dictionary_entries/${region.data.entry_id}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken
        },
        body: JSON.stringify(updateData),
      })
        .then(_data => {
          console.log('Dictionary entry updated');
        })
        .catch(error => {
          console.error('Error updating dictionary entry:', error);
        });
    });

    this.waveSurfer.on('region-removed', function (region) {
      if (!region.data.entry_id) {
        console.log('No entry_id present in region data.');
        return;
      }

      const csrfToken = document.querySelector('meta[name="csrf-token"]').getAttribute('content');

      const updateData = {
        dictionary_entry: {
          region_start: null,
          region_end: null,
          region_id: null
        }
      };

      fetch(`/dictionary_entries/${region.data.entry_id}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken
        },
        body: JSON.stringify(updateData),
      })
        .then(_data => {
          console.log('Dictionary entry updated');
        })
        .catch(error => {
          console.error('Error updating dictionary entry:', error);
        });
    });
  }

  handleKeyDown(event) {
    const seekTime = 5;

    switch (event.code) {
      case 'ArrowLeft':
        event.preventDefault();
        this.waveSurfer.seekTo(Math.max(0, this.waveSurfer.getCurrentTime() - seekTime) / this.waveSurfer.getDuration());
        break;
      case 'ArrowRight':
        event.preventDefault();
        this.waveSurfer.seekTo(Math.min(this.waveSurfer.getDuration(), this.waveSurfer.getCurrentTime() + seekTime) / this.waveSurfer.getDuration());
        break;
      case 'KeyP':
        if (event.ctrlKey) {
          event.preventDefault();
          this.waveSurfer.playPause();
          this.toggleButton();
        }
        break;
    }
  }

  addRegionAtCurrent() {
    const currentPosition = this.waveSurfer.getCurrentTime();
    const start = Math.max(0, currentPosition - 2);
    const end = currentPosition;

    if (start < end) {
      this.waveSurfer.addRegion({
        start: start,
        end: end,
        color: 'rgba(0, 255, 0, 0.1)'
      });
    }
  }

  resetForm(target) {
    let regionId = document.getElementById('dictionary_entry_region_id').value;
    let region = this.waveSurfer.regions.list[regionId];
    if (region) {
      target.reset()
    }
  }

  zoom(event) {
    event.preventDefault()
    this.waveSurfer.zoom(Number(event.target.value));
  }

  play(event) {
    event.preventDefault()
    const regionId = event.currentTarget.dataset.regionId;
    const region = this.waveSurfer.regions.list[regionId]
    if (region) {
      region.play()
    } else {
      this.waveSurfer.playPause()
    }
    this.toggleButton();
  }

  seek(position) {
    if (this.waveSurfer && this.waveSurfer.getDuration()) {
      const normalizedPosition = position / this.waveSurfer.getDuration();
      this.waveSurfer.seekTo(normalizedPosition);
    }
  }

  handleSeekEvent(event) {
    const position = event.detail.position;
    const entryId = event.detail.regionId; // This is actually the dictionary entry ID
    
    console.log('Seek event received:', { position, entryId });
    
    // Find the region by entry_id in the region data first to get zoom info
    let targetRegion = null;
    if (entryId !== null && entryId !== undefined && this.waveSurfer && this.waveSurfer.regions) {
      console.log('Available regions:', Object.keys(this.waveSurfer.regions.list));
      
      // Find region by entry_id instead of region ID
      Object.values(this.waveSurfer.regions.list).forEach(region => {
        if (region.data && region.data.entry_id == entryId) {
          targetRegion = region;
        }
      });
      
      console.log('Found region:', targetRegion);
      
      // Zoom to the region with padding before seeking
      if (targetRegion) {
        this.zoomToRegion(targetRegion);
      }
    }
    
    // Seek to the position
    this.seek(position);
    
    // Play the region if found
    if (targetRegion && typeof targetRegion.play === 'function') {
      console.log('Playing region...');
      // Small delay to ensure seek and zoom complete before playing
      setTimeout(() => {
        targetRegion.play();
        this.toggleButton(); // Update the play/pause button state
      }, 200);
    } else if (entryId !== null && entryId !== undefined) {
      console.log(`Region with entry ID ${entryId} not found or cannot play`);
      console.log('Region object:', targetRegion);
      console.log('Region play function:', targetRegion ? typeof targetRegion.play : 'no region');
    } else {
      console.log('Missing requirements:', {
        entryId: entryId !== null && entryId !== undefined,
        waveSurfer: !!this.waveSurfer,
        regions: !!(this.waveSurfer && this.waveSurfer.regions)
      });
    }
  }

  zoomToRegion(region) {
    if (!this.waveSurfer || !region) return;
    
    const duration = this.waveSurfer.getDuration();
    const regionDuration = region.end - region.start;
    
    // Add padding before and after the region (2 seconds on each side, or 50% of region duration, whichever is smaller)
    const paddingTime = Math.min(2.0, regionDuration * 0.5);
    const zoomStart = Math.max(0, region.start - paddingTime);
    const zoomEnd = Math.min(duration, region.end + paddingTime);
    const zoomDuration = zoomEnd - zoomStart;
    
    // Calculate zoom level to fit the padded region in the visible area
    // Aim for the region + padding to take up most of the waveform width
    const containerWidth = this.waveSurfer.container.clientWidth;
    const desiredPixelsPerSecond = containerWidth / zoomDuration;
    
    // Apply a reasonable zoom level (clamp between 50 and 2000 pixels per second)
    const clampedZoom = Math.max(50, Math.min(2000, desiredPixelsPerSecond));
    
    console.log('Zooming to region:', {
      regionStart: region.start,
      regionEnd: region.end,
      regionDuration: regionDuration,
      paddingTime: paddingTime,
      zoomStart: zoomStart,
      zoomEnd: zoomEnd,
      zoomDuration: zoomDuration,
      pixelsPerSecond: clampedZoom
    });
    
    // Apply zoom
    this.waveSurfer.zoom(clampedZoom);
  }

  toggleButton() {
    const button = this.element.querySelector('#play-pause-button')
    if (!button) return;

    const isPlaying = this.waveSurfer.isPlaying();
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
        button.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zM7 8a1 1 0 012 0v4a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v4a1 1 0 102 0V8a1 1 0 00-1-1z" clip-rule="evenodd" /></svg><span>Pause</span>';
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
        button.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z" clip-rule="evenodd" /></svg><span>Play</span>';
      }
      button.setAttribute('aria-label', 'Play');
    }
  }

  formatTime(seconds) {
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs < 10 ? '0' : ''}${secs}`;
  }

  showSaveButton(region) {
    // Only show save button if region doesn't have an existing entry_id
    if (region.data && region.data.entry_id) {
      return;
    }

    // Remove any existing save button
    this.hideSaveButton();

    // Create save button container
    const saveContainer = document.createElement('div');
    saveContainer.id = 'save-region-container';
    saveContainer.className = 'fixed top-4 right-4 bg-white border border-gray-300 rounded-lg shadow-lg p-4 z-50';
    
    const message = document.createElement('p');
    message.className = 'text-sm text-gray-700 mb-3';
    message.textContent = 'New region created! Save as dictionary entry?';
    
    const buttonContainer = document.createElement('div');
    buttonContainer.className = 'flex gap-2';
    
    const saveButton = document.createElement('button');
    saveButton.className = 'bg-green-600 hover:bg-green-700 text-white px-3 py-1 rounded text-sm';
    saveButton.textContent = 'Save';
    saveButton.onclick = () => this.saveRegion(region);
    
    const cancelButton = document.createElement('button');
    cancelButton.className = 'bg-gray-400 hover:bg-gray-500 text-white px-3 py-1 rounded text-sm';
    cancelButton.textContent = 'Cancel';
    cancelButton.onclick = () => {
      this.hideSaveButton();
      region.remove();
    };
    
    buttonContainer.appendChild(saveButton);
    buttonContainer.appendChild(cancelButton);
    saveContainer.appendChild(message);
    saveContainer.appendChild(buttonContainer);
    
    document.body.appendChild(saveContainer);
  }

  hideSaveButton() {
    const existingContainer = document.getElementById('save-region-container');
    if (existingContainer) {
      existingContainer.remove();
    }
  }

  async saveRegion(region) {
    try {
      const csrfToken = document.querySelector('meta[name="csrf-token"]').getAttribute('content');
      const voiceRecordingId = window.location.pathname.match(/voice_recordings\/(\d+)/)[1];
      
      const entryData = {
        dictionary_entry: {
          region_start: region.start,
          region_end: region.end,
          region_id: region.id,
          voice_recording_id: voiceRecordingId,
          word_or_phrase: '',
          translation: ''
        }
      };

      const response = await fetch(`/voice_recordings/${voiceRecordingId}/dictionary_entries`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken,
          'Accept': 'application/json'
        },
        body: JSON.stringify(entryData)
      });

      if (response.ok) {
        const result = await response.json();
        
        // Update region data with the new entry_id
        region.data = { entry_id: result.id };
        
        // Hide the save button
        this.hideSaveButton();
        
        // Refresh the entries list
        this.refreshEntriesList();
        
        console.log('Region saved successfully as dictionary entry');
      } else {
        throw new Error('Failed to save region');
      }
    } catch (error) {
      console.error('Error saving region:', error);
      alert('Failed to save region. Please try again.');
    }
  }

  async refreshEntriesList() {
    try {
      const voiceRecordingId = window.location.pathname.match(/voice_recordings\/(\d+)/)[1];
      const currentPage = new URLSearchParams(window.location.search).get('page') || 1;
      
      const response = await fetch(`/voice_recordings/${voiceRecordingId}/dictionary_entries?page=${currentPage}`, {
        headers: {
          'Accept': 'text/vnd.turbo-stream.html'
        }
      });
      
      if (response.ok) {
        const html = await response.text();
        Turbo.renderStreamMessage(html);
      }
    } catch (error) {
      console.error('Error refreshing entries list:', error);
    }
  }
}
