import { Controller } from "@hotwired/stimulus"
import WaveSurfer from "wavesurferjs"
import RegionsPlugin from 'wavesurferregionsjs';
import autoComplete from "autocomplete";

export default class extends Controller {
  static targets = ["time", "wordSearch", "tagSearch", "waveform", "startRegion", "endRegion", "regionId", "transcription", "translation", "engSubs", "gaeSubs"]
  static values = { media: String, regions: Array }

  initialize() {
    addEventListener("turbo:submit-end", ({ target }) => {
      this.resetForm(target)
    })
  }

  resetForm(target) {
    try {
      if (target.elements['dictionary_entry[media]'] instanceof RadioNodeList) {
        target.elements['dictionary_entry[media]'].forEach((item) => {
          if (item.type === "hidden") {
            item.remove()
          }
        })
      }
      let transcription = target.elements['dictionary_entry[word_or_phrase]'].value;
      let translation = target.elements['dictionary_entry[translation]'].value;
      let regionId = target.elements['dictionary_entry[region_id]'].value;
      if (regionId) {
        let region = this.waveSurfer.regions.list[regionId];
        region.update({ data: { transcription: transcription, translation: translation } })
      }
    } finally {
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
      // waveColor: 'violet',
      // progressColor: 'purple',
      partialRender: false,
      pixelRatio: 1,
      scrollParent: true,
      // normalize: true,
      plugins: [
        RegionsPlugin.create({
          dragSelection: true,
        })
      ]
    })

    this.waveSurfer.load(this.mediaValue);

    this.waveSurfer.on('loading', function (progress) {
      if (progress < 99) {
        playButton.innerHTML = `loading ${progress}%`;
      } else {
        playButton.innerHTML = "Play / Pause";
      }
    })

    this.waveSurfer.on('ready', function() {
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

    this.waveSurfer.on('audioprocess', function () {
      if (that.waveSurfer.isPlaying() && that.hasTimeTarget) {
        that.timeTarget.innerText = that.waveSurfer.getCurrentTime().toFixed(1)
      }
    })

    this.waveSurfer.on('seek', function() {
      if (that.hasTimeTarget) {
        that.timeTarget.innerText = that.waveSurfer.getCurrentTime().toFixed(1)
      }
    })

    this.waveSurfer.on('region-click', function (region, e) {
      e.stopPropagation();
      // // Play on click, loop on shift click
      e.shiftKey ? region.playLoop() : region.play();
    })

    this.waveSurfer.on('region-click', function (region) {
      that.startRegionTarget.children[0].value = Math.round(region.start * 10) / 10
      that.endRegionTarget.children[0].value = Math.round(region.end * 10) / 10
      that.regionIdTarget.children[0].value = region.id
    })
  }

  wordSearchTargetConnected() {
    const abairtSearch = new autoComplete({
      selector: "#autoComplete",
      placeHolder: "Déan cuardach ar focal...",
      debounce: 300,
      threshold: 2,
      data: {
        src: async (query) => {
          try {
            // Fetch Data from external Source
            const source = await fetch(`/dictionary_entries?search=${query.replace(/\W/g, '')}`, { headers: { accept: "application/json" } });
            // Data is array of `Objects` | `Strings`
            const data = await source.json();

            return data;
          } catch (error) {
            return error;
          }
        },
        keys: ['word_or_phrase']
      },
      resultItem: {
        highlight: {
          render: true
        }
      },
      events: {
        input: {
          selection: (event) => {
            console.log
            document.getElementById("dictionary_entry_id").value = event.detail.selection.value["id"]
            abairtSearch.input.value = event.detail.selection.value["word_or_phrase"]
            document.getElementById("translation").value = event.detail.selection.value["translation"]
            document.getElementById("notes").value = event.detail.selection.value["notes"]
            document.getElementById("autoCompleteTags").value = event.detail.selection.value["tag_list"]
          }
        }
      }
    })
  }

  tagSearchTargetConnected() {
    const tagsSearch = new autoComplete({
      selector: "#autoCompleteTags",
      placeHolder: "Déan cuardach ar clib...",
      debounce: 300,
      data: {
        src: async (query) => {
          try {
            // Fetch Data from external Source
            const source = await fetch(`/tags?search=${query.replace(/\W/g, '')}`, { headers: { accept: "application/json" } });
            // Data is array of `Objects` | `Strings`
            const data = await source.json();

            return data;
          } catch (error) {
            return error;
          }
        },
        keys: ['name']
      },
      resultItem: {
        highlight: {
          render: true
        }
      },
      events: {
        input: {
          selection: (event) => {
            const selection = event.detail.selection.value['name'];
            tagsSearch.input.value = selection;
          }
        }
      }
    })
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
    } else {
      this.waveSurfer.playPause()
    }
  }
}
