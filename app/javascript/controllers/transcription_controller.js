import { Controller } from "@hotwired/stimulus"
import WaveSurfer from "wavesurferjs"
import RegionsPlugin from 'wavesurferregionsjs';

export default class extends Controller {
  static targets = ["time", "wordSearch", "tagSearch", "waveform", "transcription", "translation", "engSubs", "gaeSubs", "video", "position"]
  static values = { media: String, regions: Array, peaks: String, autoplay: Boolean }

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

  handleKeyDown(event) {
    const seekTime = 5; // Number of seconds to seek

    switch (event.code) {
      case 'ArrowLeft':
        event.preventDefault(); // Prevent the default action (scrolling)
        this.waveSurfer.seekTo(Math.max(0, this.waveSurfer.getCurrentTime() - seekTime) / this.waveSurfer.getDuration());
        break;
      case 'ArrowRight':
        event.preventDefault(); // Prevent the default action (scrolling)
        this.waveSurfer.seekTo(Math.min(this.waveSurfer.getDuration(), this.waveSurfer.getCurrentTime() + seekTime) / this.waveSurfer.getDuration());
        break;
      case 'KeyP':
        if (event.ctrlKey) {
          event.preventDefault(); // Prevent the default action
          this.waveSurfer.playPause();
          this.toggleButton(); // Update the button text accordingly
        }
        break;
    }
  }


  addRegionAtCurrent() {
    // Get the current playback position
    const currentPosition = this.waveSurfer.getCurrentTime();

    // Find the end of the last region
    let lastRegionEnd = 0;
    Object.keys(this.waveSurfer.regions.list).forEach(key => {
      const region = this.waveSurfer.regions.list[key];
      if (region.end > lastRegionEnd) {
        lastRegionEnd = region.end;
      }
    });

    // Ensure the new region does not start before the last region ends
    const start = Math.max(lastRegionEnd, currentPosition - 5); // Adjust 5 seconds before current if needed
    const end = currentPosition;

    // Add the new region if it makes sense (start must be less than end)
    if (start < end) {
      this.waveSurfer.addRegion({
        start: start,
        end: end,
        color: 'rgba(0, 255, 0, 0.1)' // Example color, change as needed
      });
    } else {
      console.error('Invalid region boundaries. Start time must be less than end time.');
    }
  }

  resetForm(target) {
    let transcription = "pending";
    let translation = "pending";
    let regionId = document.getElementById('dictionary_entry_region_id').value;
    let region = this.waveSurfer.regions.list[regionId];
    if (region) {
      region.update({ data: { transcription: transcription, translation: translation } })
      target.reset()
    }
  }

  zoom(event) {
    event.preventDefault()
    this.waveSurfer.zoom(Number(event.target.value));
  }

  async fetchPeaksData() {
    if (this.hasPeaksValue) {
      try {
        let response = await fetch(this.peaksValue);
        await response.json();
      } catch (error) {
        console.error('Error fetching peaks data:', error);
      }
    }
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
      // peaks: that.fetchPeaksData(), // FIXME
      plugins: [
        RegionsPlugin.create({
          dragSelection: true,
        })
      ]
    })
    const mediaFile = (this.hasVideoTarget ? this.videoTarget : this.mediaValue);
    this.waveSurfer.load(mediaFile);

    this.waveSurfer.on('loading', function (progress) {
      playButton.classList.remove("cursor-not-allowed");
      if (progress < 99) {
        playButton.innerHTML = `loading ${progress}%`;
      } else {
        playButton.innerHTML = "Play";
      }
    })

    this.waveSurfer.on('ready', function() {
      playButton.innerHTML = "Play";
      that.regionsValue.forEach((region) => {
        that.waveSurfer.addRegion({
          id: region.region_id,
          start: region.region_start,
          end: region.region_end,
          drag: false,
          data: { transcription: region.word_or_phrase, translation: region.translation, entry_id: region.id }
        });
      })
      if (that.autoplayValue) {
        that.waveSurfer.play(); // Add this line to start playing automatically
        playButton.innerHTML = "Pause";
      }
    })

    this.waveSurfer.on('region-in', (region) => {
      if (that.gaeSubsTarget.checked) {
        that.transcriptionTarget.innerText = region.data.transcription
      }
      if (that.engSubsTarget.checked) {
        that.translationTarget.innerText = region.data.translation
      }
    });

    this.waveSurfer.on('region-out', (region) => {
      that.transcriptionTarget.innerText = "~";
      that.translationTarget.innerText = "~";
    });

    this.waveSurfer.on('audioprocess', function () {
      if (that.waveSurfer.isPlaying() && that.hasTimeTarget) {
        that.timeTarget.innerText = that.formatTime(that.waveSurfer.getCurrentTime().toFixed(1))
        if (that.hasPositionTarget) {
          that.positionTarget.value = that.waveSurfer.getCurrentTime().toFixed(1)
        }
        if (document.getElementById('current-position')) {
          document.getElementById('current-position').value = that.waveSurfer.getCurrentTime().toFixed(2);
        }
      }
    })

    this.waveSurfer.on('seek', function() {
      if (that.hasTimeTarget) {
        that.timeTarget.innerText = that.waveSurfer.getCurrentTime().toFixed(1)
      }
      if (that.hasPositionTarget) {
        that.positionTarget.value = that.waveSurfer.getCurrentTime().toFixed(2)
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
      // // Play on click, loop on shift click
      if (e.altKey) {
        // alt/option + click logic here (e.g., region.remove())
        // Confirm dialog before proceeding with the destructive action
        if (!confirm('Are you sure you want to delete this region? This action cannot be undone.')) {
          console.log('Region deletion cancelled.');
          return;
        }
        region.remove();
      } else if (e.shiftKey) {
        region.playLoop();
      } else {
        // Single click logic here (e.g., region.play())
        region.play();
      }
    })


    this.waveSurfer.on('region-click', function (region) {
      const regionStartInput = document.getElementById('dictionary_entry_region_start');
      const regionEndInput = document.getElementById('dictionary_entry_region_end');
      const regionIdInput = document.getElementById('dictionary_entry_region_id');

      if (regionStartInput && regionEndInput && regionIdInput) {
        regionStartInput.value = Math.round(region.start * 10) / 10;
        regionEndInput.value = Math.round(region.end * 10) / 10;
        regionIdInput.value = region.id;
      }
    });

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

      // Construct the URL using the entry_id stored in the region's data
      const url = `/dictionary_entries/${region.data.entry_id}`;

      // Send the data to the backend using fetch API or your preferred method
      fetch(url, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken // Include CSRF token in the request header
        },
        body: JSON.stringify(updateData),
      })
        .then(_data => {
          // Log success, no need to update UI here as it's already up-to-date
          console.log('Dictionary entry updated');
        })
        .catch(error => {
          console.error('Error updating dictionary entry:', error);
        });
    });

    this.waveSurfer.on('region-removed', function (region) {
      // Early return if entry_id is not present in region data
      if (!region.data.entry_id) {
        console.log('No entry_id present in region data.');
        return;
      }

      // Get CSRF token from meta tag
      const csrfToken = document.querySelector('meta[name="csrf-token"]').getAttribute('content');

      // Prepare the data to be sent
      const updateData = {
        dictionary_entry: {
          region_start: null,
          region_end: null,
          region_id: null
        }
      };

      // Construct the URL using the entry_id stored in the region's data
      const url = `/dictionary_entries/${region.data.entry_id}`;

      // Send the data to the backend using fetch API or your preferred method
      fetch(url, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken // Include CSRF token in the request header
        },
        body: JSON.stringify(updateData),
      })
        .then(_data => {
          // Log success, no need to update UI here as it's already up-to-date
          console.log('Dictionary entry updated');
        })
        .catch(error => {
          console.error('Error updating dictionary entry:', error);
        });
    });
  }

  teardown() {
    this.waveSurfer.destroy()
    this.waveSurfer = null;
    this.meeting = null;
  }

  slower(event) {
    event.preventDefault()
    const button = this.element.querySelector('#play-pause-button')
    let currentSpeed = this.waveSurfer.getPlaybackRate()
    if (currentSpeed <= 0.33) {
      this.waveSurfer.setPlaybackRate(1)
      button.innerHTML = "Pause"
    } else {
      this.waveSurfer.setPlaybackRate((currentSpeed * 0.75))
      button.innerHTML = "Reset"
    }
  }

  play(event) {
    event.preventDefault()
    const regionId = event.currentTarget.dataset.regionId;
    const region = this.waveSurfer.regions.list[regionId]
    if (region) {
      region.play()
    } else if (this.waveSurfer.getPlaybackRate() < 1) {
      this.waveSurfer.setPlaybackRate(1)
    } else {
      this.waveSurfer.playPause()
    }
    this.toggleButton();
  }

  toggleButton() {
    const button = this.element.querySelector('#play-pause-button')
    if (this.waveSurfer.isPlaying() && (this.waveSurfer.getPlaybackRate() < 1)) {
      button.innerHTML = "Reset"
    } else if (this.waveSurfer.isPlaying()) {
      button.innerHTML = "Pause"
    } else {
      button.innerHTML = "Play"
    }
  }

  seek(seekPosition) {
    const value = seekPosition / this.waveSurfer.getDuration();
    this.waveSurfer.seekTo(value);
  }

  formatTime(seconds) {
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs < 10 ? '0' : ''}${secs}`;
  }
}
