import { Controller } from "stimulus"

export default class extends Controller {
  static targets = ["cell"]
  static values = { meetingId: String }

  initialize() {
    console.log("meeting id is", this.meetingIdValue)
  }

  hide() {
    this.cellTargets.forEach((cellTarget) => {
      cellTarget.classList.toggle("hidden")
    })
  }

  startMeeting() {
    const domain = 'meet.jit.si';
    const options = {
      roomName: this.meetingIdValue,
      height: 700,
      parentNode: document.querySelector('#meet')
    };
    const api = new JitsiMeetExternalAPI(domain, options);
  }
}
