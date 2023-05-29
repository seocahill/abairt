import { Controller } from "@hotwired/stimulus"
import feather from "feather-icons"

export default class extends Controller {
  static targets = ["dropdown", "audio", "translation", "abairt", "notes", "media", "status", "word", "template"]
  static values = { url: String, id: Number }

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

  show() {
    this.dropdownTarget.classList.remove("hidden")
  }

  hide() {
    this.dropdownTarget.classList.add("hidden")
  }
}
