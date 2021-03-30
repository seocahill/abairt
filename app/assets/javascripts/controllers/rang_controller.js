import { Controller } from "stimulus"

export default class extends Controller {
  static targets = ["cell"]

  connect() {
    // this.startMeeting()
  }

  hide() {
    this.cellTargets.forEach((cellTarget) => {
      cellTarget.classList.toggle("hidden")
    })
  }

  startMeeting() {
    const domain = 'meet.jit.si';
    const options = {
      roomName: `abairt-${Math.random().toString(16).substr(2, 8)}`,
      height: 700,
      parentNode: document.querySelector('#meet')
    };
    const api = new JitsiMeetExternalAPI(domain, options);
  }
}
