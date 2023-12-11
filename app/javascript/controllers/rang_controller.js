import { Controller } from "@hotwired/stimulus"
import autoComplete from "autocomplete";
import feather from "feather-icons"

export default class extends Controller {
  static targets = ["cell", "dropdown", "time", "wordSearch", "list"]
  static values = { meetingId: String, media: String, currentUserId: String }
  scrollDirectionDown = true;

  initialize() {
    addEventListener("turbo:submit-end", ({ target }) => {
      this.resetForm(target)
    })
  }

  connect() {
    feather.replace()
  }

  prevMessages(e) {
    e.preventDefault()
    document.querySelectorAll('.previous-messages').forEach(node => node.classList.remove('hidden'));
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
    } finally {
      target.reset()
    }
  }


  wordSearchTargetConnected() {
    const that = this;
    const abairtSearch = new autoComplete({
      selector: "#autoCompleteWord",
      placeHolder: "Irish: duplicates will be shown if exists...",
      debounce: 300,
      threshold: 2,
      wrapper: false,
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
            let entryId = event.detail.selection.value["id"]
            that.addRangEntry(entryId)
          }
        }
      }
    })
  }

  addRangEntry(entryId) {
    let formData = new FormData()
    formData.append("rang[dicionary_entry_ids][]", entryId)
    fetch(`/rangs/${this.idValue}`, {
      body: formData,
      method: 'PATCH',
      credentials: "include",
      dataType: "script",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
    });
  }

  teardown() {
    this.meeting = null;
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

  startMeeting() {
    const domain = 'meet.jit.si';
    const meetingNode = document.querySelector('#meet')
    meetingNode.classList.add("w-full")
    const options = {
      roomName: this.meetingIdValue,
      height: 700,
      parentNode: meetingNode
    };
    this.meeting = new JitsiMeetExternalAPI(domain, options);
    document.querySelector('#call').classList.add("hidden")
    document.querySelector('#hang-up').classList.remove("hidden")
  }

  endMeeting() {
    this.meeting.dispose();
    document.querySelector('#call').classList.remove("hidden")
    document.querySelector('#hang-up').classList.add("hidden")
  }
}
