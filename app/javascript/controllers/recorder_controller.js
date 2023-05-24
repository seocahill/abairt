import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage";

export default class extends Controller {
  static targets = ["input", "recordButton", "stopButton"]
  static values = { autosave: Boolean }

  connect() {
    this.stopButtonTarget.classList.toggle('hidden')
  }

  record(event) {
    event.preventDefault()
    this.chunks = []
    this.stream().then(stream => {
      this._stream = stream
      this.flipButtons()
      this.recorder().start(1000)
    })
  }

  stop(event) {
    event.preventDefault()
    this.flipButtons()
    this.recorder().stop()
  }

  stream() {
    if (this._stream == undefined) {
      return navigator.mediaDevices.getUserMedia({ audio: true })
    }
    return this._stream
  }

  recorder() {
    if (this._recorder == undefined) {
      let that = this
      this._recorder = new MediaRecorder(this.stream())
      this._recorder.ondataavailable = function (e) {
        that.chunks.push(e.data)
      }
      this._recorder.onstop = function (e) {
        const file = new File(that.chunks, 'audio.ogg', { type: 'audio/ogg' })
        const upload = new DirectUpload(file, that.url())
        upload.create((error, blob) => {
          that.hiddenInput = document.createElement('input')
          that.hiddenInput.type = 'hidden'
          that.hiddenInput.name = that.inputTarget.name
          that.hiddenInput.value = blob.signed_id
          that.hiddenInput.setAttribute("data-target", "entry.media");
          that.inputTarget.parentNode.insertBefore(that.hiddenInput, that.inputTarget.nextSibling)
          console.log(that.autosaveValue)
          if (that.element.parentNode.querySelector('audio')) {
            that.element.parentNode.querySelector('audio').setAttribute('src', `/rails/active_storage/blobs/redirect/${blob.signed_id}/audio.ogg`)
          } else if (that.autosaveValue) {
            console.log("submitting", that.hiddenInput)
            setTimeout(() => {
              Turbo.navigator.submitForm(that.element.parentNode)
            }, 500); // Adjust the delay as needed
          }
        })
        that._stream = null;
      }
    }
    return this._recorder
  }

  flipButtons() {
    this.recordButtonTarget.classList.toggle('hidden')
    this.stopButtonTarget.classList.toggle('hidden')
  }

  url() {
    return this.inputTarget.getAttribute('data-direct-upload-url')
  }
}