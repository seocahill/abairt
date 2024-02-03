import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage";

export default class extends Controller {
  static targets = ["input", "synthesizeButton", "word", "media"]
  static values = { url: String }

  connect() {
    console.info("connected to tts controller")
  }

  async synthesizeAndUpload(event) {
    event.preventDefault();
    const text = this.wordTarget.value; // Get the text from your word_or_phrase input field
    const response = await this.synthesizeSpeech(text);
    const synthesizedAudioBase64 = response.audioContent;

    // Convert base64 audio data to a Blob
    const audioBlob = this.base64ToBlob(synthesizedAudioBase64, 'audio/ogg');
    const file = new File([audioBlob], 'audio.ogg', { type: 'audio/ogg' });

    // Direct upload to storage
    const upload = new DirectUpload(file, this.urlValue);
    upload.create((error, blob) => {
      if (error) {
        console.error(error)
      } else {
        this.createHiddenInput(blob.signed_id);
        setTimeout(() => {
          Turbo.navigator.submitForm(this.element.parentNode)
        }, 500); // Adjust the delay as needed
      }
    });
  }

  createHiddenInput(signedId) {
    const hiddenInput = document.createElement('input');
    hiddenInput.type = 'hidden';
    hiddenInput.name = this.inputTarget.name;
    hiddenInput.value = signedId;
    hiddenInput.setAttribute("data-target", "entry.media");
    this.inputTarget.parentNode.insertBefore(hiddenInput, this.inputTarget.nextSibling);
  }

  base64ToBlob(base64, mimeType) {
    const byteCharacters = atob(base64);
    const byteNumbers = new Array(byteCharacters.length);
    for (let i = 0; i < byteCharacters.length; i++) {
      byteNumbers[i] = byteCharacters.charCodeAt(i);
    }
    const byteArray = new Uint8Array(byteNumbers);
    return new Blob([byteArray], { type: mimeType });
  }

  async synthesizeSpeech(text) {
    const uri = 'https://abair.ie/api2/synthesise';
    const requestBody = {
      synthinput: { text: text, ssml: 'string' },
      voiceparams: { languageCode: 'ga-IE', name: "ga_UL_anb_nemo", ssmlGender: 'UNSPECIFIED' },
      audioconfig: { audioEncoding: 'LINEAR16', speakingRate: 1, pitch: 1, volumeGainDb: 1 },
      outputType: 'JSON'
    };

    const response = await fetch(uri, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(requestBody)
    });

    return await response.json();  // assuming the response is directly the base64 string of the audio.
  }
}
