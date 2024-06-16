import { Controller } from "@hotwired/stimulus"
import WaveSurfer from "wavesurferjs"
import RegionsPlugin from 'wavesurferregionsjs';

export default class extends Controller {
  static targets = ["time", "wordSearch", "tagSearch", "waveform", "transcription", "translation", "engSubs", "gaeSubs", "video", "position"]
  static values = { media: String, regions: Array, peaks: Array, autoplay: Boolean }

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
    })
  }

  handleKeyDown(event) {
    if (event.code === 'Space') {
      event.preventDefault(); // Prevent the default action of the spacebar (scrolling)
      this.waveSurfer.playPause();
      this.toggleButton(); // Update the button text accordingly
    }
  }

  resetForm(target) {
    let transcription = document.getElementById('dictionary_entry_word_or_phrase').value;
    let translation = document.getElementById('dictionary_entry_translation').value;
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
      peaks: that.peaksValue,
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
      if (document.getElementById('prev-position')) {
        document.getElementById('prev-position').value = parseFloat(that.waveSurfer.getCurrentTime().toFixed(2)) + 0.01;
      }
    });

    this.waveSurfer.on('audioprocess', function () {
      if (that.waveSurfer.isPlaying() && that.hasTimeTarget) {
        that.timeTarget.innerText = that.waveSurfer.getCurrentTime().toFixed(1)
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

    this.waveSurfer.on('region-click', function (region, e) {
      e.stopPropagation();
      // // Play on click, loop on shift click
      if (e.altKey) {
        // alt/option + click logic here (e.g., region.remove())
        region.remove();
      } else if (e.shiftKey) {
        region.playLoop();
      } else {
        // Single click logic here (e.g., region.play())
        region.play();
      }
    })

    this.waveSurfer.on('region-click', function (region) {
      document.getElementById('dictionary_entry_region_start').value = Math.round(region.start * 10) / 10
      document.getElementById('dictionary_entry_region_end').value = Math.round(region.end * 10) / 10
      document.getElementById('dictionary_entry_region_id').value = region.id
    })

    this.waveSurfer.on('region-update-end', function (region) {
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
        .then(response => response.json())
        .then(data => {
          // Log success, no need to update UI here as it's already up-to-date
          console.log('Dictionary entry updated:', data);
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
}
