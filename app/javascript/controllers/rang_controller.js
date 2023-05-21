import { Controller } from "@hotwired/stimulus"
import autoComplete from "autocomplete";

export default class extends Controller {
  static targets = ["cell", "dropdown", "time", "wordSearch", "tagSearch", "list"]
  static values = { meetingId: String, media: String, currentUserId: String }
  scrollDirectionDown = true;

  initialize() {
    addEventListener("turbo:submit-end", ({ target }) => {
      this.resetForm(target)
    })
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


  format(n) {
    let mil_s = String(n % 1000).padStart(3, '0');
    n = Math.trunc(n / 1000);
    let sec_s = String(n % 60).padStart(2, '0');
    n = Math.trunc(n / 60);
    return String(n) + ' m ' + sec_s + ' s ' + mil_s + ' ms';
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
    const options = {
      roomName: this.meetingIdValue,
      height: 700,
      parentNode: document.querySelector('#meet')
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
