import { Controller } from "stimulus"

export default class extends Controller {
  static targets = ["dropdown", "audio", "translation", "abairt", "notes", "media"]
  static values = { url: String }

  deanta(e) {
    e.preventDefault()
    let formData = new FormData()
    formData.append("dictionary_entry[word_or_phrase]", this.abairtTarget.innerText)
    formData.append("dictionary_entry[translation]", this.translationTarget.innerText)
    formData.append("dictionary_entry[notes]", this.notesTarget.innerText)
    formData.append("dictionary_entry[media]", this.mediaTarget.value)
    // formData.append("dictionary_entry[status]", "normal")
    fetch(this.urlValue, {
      body: formData,
      method: 'PATCH',
      credentials: "include",
      dataType: "script",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
    })
  }

  play(e) {
    e.preventDefault()
    this.audioTarget.play()
  }

  show() {
    this.dropdownTarget.classList.remove("hidden")
  }

  hide() {
    this.dropdownTarget.classList.add("hidden")
  }
}
