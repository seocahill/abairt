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
  }

  disconnect() {
    document.removeEventListener('keydown', this.handleKeyDown.bind(this));
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
      if (progress < 99) {
        playButton.innerHTML = `loading ${progress}%`;
      } else {
        playButton.innerHTML = "Play";
      }
    })

    this.waveSurfer.on('ready', async function() {
      playButton.innerHTML = "Play";

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

  toggleButton() {
    const button = this.element.querySelector('#play-pause-button')
    if (this.waveSurfer.isPlaying()) {
      button.innerHTML = "Pause"
    } else {
      button.innerHTML = "Play"
    }
  }

  formatTime(seconds) {
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs < 10 ? '0' : ''}${secs}`;
  }
}
