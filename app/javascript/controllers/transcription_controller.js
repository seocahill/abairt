import { Controller } from "@hotwired/stimulus"
import WaveSurfer from "wavesurferjs"
import RegionsPlugin from 'wavesurferregionsjs';

export default class extends Controller {
  static targets = ["time", "wordSearch", "tagSearch", "waveform", "transcription", "translation", "engSubs", "gaeSubs", "video"]
  static values = { media: String, regions: Array }

  initialize() {
    addEventListener("turbo:submit-end", ({ target }) => {
      this.resetForm(target)
    })
  }

  resetForm(target) {
    if (document.getElementById('dictionary_entry_media') instanceof RadioNodeList) {
      document.getElementById('dictionary_entry_media').forEach((item) => {
        if (item.type === "hidden") {
          item.remove()
        }
      })
    }
    let transcription = document.getElementById('dictionary_entry_word_or_phrase').value;
    let translation = document.getElementById('dictionary_entry_translation').value;
    let regionId = document.getElementById('dictionary_entry_region_id').value;
    if (regionId) {
      let region = this.waveSurfer.regions.list[regionId];
      region.update({ data: { transcription: transcription, translation: translation } })
    }
    target.reset()
  }

  zoom(event) {
    event.preventDefault()
    this.waveSurfer.zoom(Number(event.target.value));
  }

  waveformTargetConnected() {
    let playButton = this.element.querySelector('#play-pause-button');
    playButton.innerHTML = "Preparing wave....";
    let that = this;
    const mediaFile = this.mediaValue
    // Fetch the audio file separately with custom headers
    fetch(mediaFile, { cache: 'force-cache', headers: {
      "Cache-Control": "force-cache"
    }})
      .then(response => response.arrayBuffer())
      .then(audioData => {
        let mediaElement;
        if (this.hasVideoTarget) {
          mediaElement = this.videoTarget;
        } else {
          mediaElement = new Audio()
        }

        mediaElement.src = URL.createObjectURL(new Blob([audioData]));

        // Initialize WaveSurfer with the preloaded audio element
        this.waveSurfer = WaveSurfer.create({
          backend: 'MediaElement',
          container: '#waveform',
          audioContext: mediaElement,
          // audioContext: audio,
          partialRender: false,
          pixelRatio: 1,
          scrollParent: true,
          // normalize: true,
          plugins: [
            RegionsPlugin.create({
              dragSelection: true,
            })
          ]
        });

        this.waveSurfer.on('ready', function () {
          playButton.innerHTML = "Play / Pause";
          that.regionsValue.forEach((region) => {
            that.waveSurfer.addRegion({
              id: region.region_id,
              start: region.region_start,
              end: region.region_end,
              data: { transcription: region.word_or_phrase, translation: region.translation }
            });
          })
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
            that.timeTarget.innerText = that.waveSurfer.getCurrentTime().toFixed(1)
          }
        })

        this.waveSurfer.on('seek', function () {
          if (that.hasTimeTarget) {
            that.timeTarget.innerText = that.waveSurfer.getCurrentTime().toFixed(1)
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

        this.waveSurfer.load(mediaElement);

        this.waveSurfer.on('loading', function (progress) {
          if (progress < 99) {
            playButton.innerHTML = `loading ${progress}%`;
          } else {
            playButton.innerHTML = "Play / Pause";
          }
        })

        this.waveSurfer.on('region-click', function (region) {
          document.getElementById('dictionary_entry_region_start').value = Math.round(region.start * 10) / 10
          document.getElementById('dictionary_entry_region_end').value = Math.round(region.end * 10) / 10
          document.getElementById('dictionary_entry_region_id').value = region.id
        })
      })
      .catch(error => {
        console.log(error)
      });
  }


  format(n) {
    let mil_s = String(n % 1000).padStart(3, '0');
    n = Math.trunc(n / 1000);
    let sec_s = String(n % 60).padStart(2, '0');
    n = Math.trunc(n / 60);
    return String(n) + ' m ' + sec_s + ' s ' + mil_s + ' ms';
  }

  teardown() {
    this.waveSurfer.destroy()
    this.waveSurfer = null;
    this.meeting = null;
  }

  slower(event) {
    event.preventDefault()
    let currentSpeed = this.waveSurfer.getPlaybackRate()
    if (currentSpeed <= 0.33) {
      this.waveSurfer.setPlaybackRate(1)
    } else {
      this.waveSurfer.setPlaybackRate((currentSpeed * 0.75))
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
  }
}
