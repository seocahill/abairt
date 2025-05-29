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
    const wordListId = e.target.dataset.listId
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
    event.target.disabled = true;
    event.target.innerText = "....";
    const text = event.currentTarget.dataset.audioText;
    const response = await this.synthesizeSpeech(text, event.target);
    const synthesizedAudioBase64 = response.audioContent;
    this.playSynthesizedAudio(synthesizedAudioBase64);
    event.target.disabled = false;
    event.target.innerText = "Synth";
  }

  async synthesizeSpeech(text, target) {
    try {
      const response = await fetch('/api/text_to_speech', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({ text: text })
      });

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      return await response.json();
    } catch (error) {
      alert("It seems like the text-to-speech service is not responding at the moment. Try again later.")
      target.disabled = false;
      target.innerText = "Synth";
    }
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
