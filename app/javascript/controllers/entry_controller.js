import { Controller } from "@hotwired/stimulus"
import feather from "feather-icons"

export default class extends Controller {
  static targets = ["dropdown", "audio", "translation", "abairt", "notes", "media", "status", "word", "template"]
  static values = { url: String, id: Number, seek: Number }

  connect() {
    feather.replace()
  }

  play(e) {
    e.preventDefault()
    this.element.getElementsByTagName("audio")[0].play()
    // this.audioTarget.play()
  }

  addToList(e) {
    const wordListId = e.target.value
    let formData = new FormData()
    formData.append("word_list_dictionary_entry[dictionary_entry_id]", this.idValue)
    formData.append("word_list_dictionary_entry[word_list_id]", wordListId)
    fetch("/word_list_dictionary_entries", {
      body: formData,
      method: 'POST',
      credentials: "include",
      dataType: "script",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
    })
  }

  seek(event) {
    event.preventDefault()
    const seekPosition = this.seekValue;
    document.getElementById("wave-controller").transcription.seek(seekPosition)
  }

  show() {
    this.dropdownTarget.classList.remove("hidden")
  }

  hide() {
    this.dropdownTarget.classList.add("hidden")
  }

  async synth(event) {
    const text = event.currentTarget.dataset.audioText;
    const response = await this.synthesizeSpeech(text);
    const synthesizedAudioBase64 = response.audioContent;
    this.playSynthesizedAudio(synthesizedAudioBase64);
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

  playSynthesizedAudio(base64AudioData) {
    const audioContext = new AudioContext();
    const audioBuffer = this.base64ToArrayBuffer(base64AudioData);

    audioContext.decodeAudioData(audioBuffer, (buffer) => {
      const source = audioContext.createBufferSource();
      source.buffer = buffer;
      source.connect(audioContext.destination);
      source.start(0);
    });
  }

  base64ToArrayBuffer(base64) {
    const binaryString = window.atob(base64);
    const bytes = new Uint8Array(binaryString.length);
    for (let i = 0; i < binaryString.length; i++) {
      bytes[i] = binaryString.charCodeAt(i);
    }
    return bytes.buffer;
  }
}
