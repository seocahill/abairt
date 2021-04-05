import { Controller } from "stimulus"
import WaveSurfer from 'https://cdn.skypack.dev/wavesurfer.js';

export default class extends Controller {
  static targets = ["cell"]
  static values = { meetingId: String, media: String }

  connect() {
    if (this.mediaValue) {
      this.waveSurfer = WaveSurfer.create({
        container: '#waveform',
        waveColor: 'violet',
        progressColor: 'purple'
      })
      this.waveSurfer.load(this.mediaValue);
    }
  }

  hide() {
    this.cellTargets.forEach((cellTarget) => {
      cellTarget.classList.toggle("hidden")
    })
  }

  play(event) {
    event.preventDefault()
    this.waveSurfer.playPause()
  }

  startMeeting() {
    const domain = 'meet.jit.si';
    const options = {
      roomName: this.meetingIdValue,
      height: 700,
      parentNode: document.querySelector('#meet')
    };
    this.meeting = new JitsiMeetExternalAPI(domain, options);
  }
}
