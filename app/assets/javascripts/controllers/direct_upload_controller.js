import { Controller } from "stimulus"
import { DirectUpload } from 'https://cdn.skypack.dev/@rails/activestorage';

export default class extends Controller {
  static targets = ["input"]

  connect() {
  }

  upload() {
    const that = this
    const file = this.inputTarget.files[0]
    const url = this.inputTarget.getAttribute('data-direct-upload-url')
    const upload = new DirectUpload(file, url, this)
    upload.create((error, blob) => {
      if (error) {
        console.warn(error)
      } else {
        that.hiddenInput = document.createElement('input')
        that.hiddenInput.type = 'hidden'
        that.hiddenInput.name = that.inputTarget.name
        that.hiddenInput.value = blob.signed_id
        that.inputTarget.parentNode.insertBefore(that.hiddenInput, that.inputTarget.nextSibling)
      }
    })
  }

  directUploadWillStoreFileWithXHR(request) {
    request.upload.addEventListener("progress", event => this.directUploadDidProgress(event))
  }

  directUploadDidProgress(event) {
    const progress = (event.loaded / event.total) * 100;
    console.log('progress is...', progress)
    const root = this.element;
    root.querySelector('.progress .progress-bar').style.width = `${event.loaded * 100 / event.total}%`;
  }

}