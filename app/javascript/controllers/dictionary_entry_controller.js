import { Controller } from "@hotwired/stimulus"
import autoComplete from "autocomplete";

export default class extends Controller {
  static targets = ["wordSearch"]

  initialize() {
    addEventListener("turbo:submit-end", ({ target }) => {
      this.resetForm(target)
    })
  }

  resetForm(target) {
    if (target.elements['dictionary_entry[media]'] instanceof RadioNodeList) {
      target.elements['dictionary_entry[media]'].forEach((item) => {
        if (item.type === "hidden") {
          item.remove()
        }
      })
    }
    target.reset()
  }

  wordSearchTargetConnected() {
    const abairtSearch = new autoComplete({
      selector: "#autoCompleteEntry",
      placeHolder: "Duplicates will be shown if exists...",
      debounce: 300,
      threshold: 2,
      data: {
        src: async (query) => {
          try {
            const sanitizedQuery = query.normalize('NFD') // Convert accented characters to their base form
              .replace(/[\u0300-\u036f]/g, '') // Remove combining diacritical marks
              .replace(/[^a-zA-Z0-9]/g, ''); // Remove non-alphanumeric characters
            // Fetch Data from external Source
            const source = await fetch(`/dictionary_entries?search=${sanitizedQuery}`, { headers: { accept: "application/json" } });
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
            abairtSearch.input.value = event.detail.selection.value["word_or_phrase"]
          }
        }
      }
    })
  }

  teardown() {
  }

  hide() {
    this.cellTargets.forEach((cellTarget) => {
      cellTarget.classList.toggle("hidden")
    })
  }

  show() {
    this.dropdownTarget.classList.toggle("hidden")
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
