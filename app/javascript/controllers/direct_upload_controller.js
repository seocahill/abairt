import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from 'https://cdn.skypack.dev/@rails/activestorage';

export default class extends Controller {
  static targets = ["input"]

  connect() {
    // Listen for the custom audio:recorded event
    this.element.addEventListener("audio:recorded", this.uploadAudio.bind(this));
  }

  disconnect() {
    this.element.removeEventListener("audio:recorded", this.uploadAudio.bind(this));
  }

  // Original upload method for file inputs (backwards compatible)
  upload() {
    const file = this.inputTarget.files[0]
    if (!file) return;
    
    this.updateStatus("Uploading...");
    const url = this.inputTarget.getAttribute('data-direct-upload-url')
    const upload = new DirectUpload(file, url, this)
    
    upload.create((error, blob) => {
      if (error) {
        console.warn(error)
        this.updateStatus("Upload failed");
      } else {
        this.setSignedId(blob.signed_id);
        this.inputTarget.value = null;
      }
    })
  }

  // New method to handle audio blob uploads
  uploadAudio(event) {
    const audioBlob = event.detail.audioBlob;
    const file = new File([audioBlob], 'recording.webm', { type: audioBlob.type });
    
    this.updateStatus("Uploading...");
    const url = this.inputTarget.getAttribute('data-direct-upload-url');
    const upload = new DirectUpload(file, url, this);
    
    upload.create((error, blob) => {
      if (error) {
        console.warn("Direct upload error:", error);
        this.updateStatus("Upload failed");
      } else {
        this.setSignedId(blob.signed_id);
        console.log("Audio upload successful, signed_id:", blob.signed_id);
      }
    });
  }

  // Helper method to set signed_id (used by both upload methods)
  setSignedId(signedId) {
    // Clear any existing hidden input
    if (this.hiddenInput) {
      this.hiddenInput.remove();
    }
    
    // Create new hidden input with signed_id
    this.hiddenInput = document.createElement('input');
    this.hiddenInput.type = 'hidden';
    this.hiddenInput.name = this.inputTarget.name;
    this.hiddenInput.value = signedId;
    this.inputTarget.parentNode.insertBefore(this.hiddenInput, this.inputTarget.nextSibling);
  }

  // Helper method to update status display
  updateStatus(message) {
    const fileNameElement = this.element.querySelector('.file-name');
    if (fileNameElement) {
      fileNameElement.innerHTML = message;
    }
  }

  directUploadWillStoreFileWithXHR(request) {
    request.upload.addEventListener("progress", event => this.directUploadDidProgress(event))
  }

  directUploadDidProgress(event) {
    const progress = Math.round((event.loaded / event.total) * 100);
    console.log('progress is...', progress)
    const root = this.element;
    const progressBar = root.querySelector('.progress .progress-bar');
    const percentageElement = root.querySelector('.percentage-uploaded');
    
    if (progressBar) {
      progressBar.style.width = `${progress}%`;
    }
    if (percentageElement) {
      percentageElement.innerHTML = `${progress}%`;
    }
    
    if (progress > 99) {
      // Determine if this was a file upload or audio recording
      const fileName = this.inputTarget.files[0] ? this.inputTarget.files[0].name : 'recording.webm';
      this.updateStatus(`${fileName} uploaded successfully`);
    }
  }
}