import { Controller } from "stimulus"
export default class extends Controller {
  static targets = ["cell", "dropdown", "time"]
  static values = { meetingId: String, media: String }

  connect() {
    let playButton = this.element.querySelector('#play-pause-button');
    let that = this;
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
      this.waveSurfer.on('audioprocess', function () {
        if (that.waveSurfer.isPlaying()) {
          that.timeTarget.innerText = that.waveSurfer.getCurrentTime().toFixed(1)
        }
      })
      this.waveSurfer.on('seek', function() {
        that.timeTarget.innerText = that.waveSurfer.getCurrentTime().toFixed(1)
      })
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
    this.waveSurfer.destroy()
    this.waveSurfer = null;
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
