import { Controller } from "stimulus"
import WaveSurfer from 'https://cdn.skypack.dev/wavesurfer.js';

export default class extends Controller {
  static targets = ["cell"]
  static values = { meetingId: String, media: String }

  connect() {
    let playButton = this.element.querySelector('#play-pause-button');
    if (this.mediaValue) {
      this.waveSurfer = WaveSurfer.create({
        container: '#waveform',
        waveColor: 'violet',
        progressColor: 'purple',
        partialRender: true
      })
      this.waveSurfer.load(this.mediaValue);
      this.waveSurfer.on('loading', function (progress) {
        if (progress && progress < 99) {
          playButton.innerHTML = `loading ${progress}%`;
        } else {
          playButton.innerHTML = "Preparing wave....";
        }
      })
      this.waveSurfer.on('ready', function() {
        playButton.innerHTML = "Play / Pause"
      })
    }
  }

  teardown() {
    this.waveSurfer.destroy()
    this.waveSurfer = null;
    this.meeting = null;
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
