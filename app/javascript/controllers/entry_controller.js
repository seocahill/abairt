import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dropdown", "audio", "translation", "abairt", "notes", "media", "status", "word", "template"]
  static values = { url: String, id: Number }

  async deanta(e) {
    e.preventDefault()
    let formData = new FormData()
    formData.append("dictionary_entry[word_or_phrase]", this.abairtTarget.innerText)
    formData.append("dictionary_entry[translation]", this.translationTarget.innerText)
    formData.append("dictionary_entry[notes]", this.notesTarget.innerText)
    if (this.hasMediaTarget) {
      formData.append("dictionary_entry[media]", this.mediaTarget.value)
    }
    formData.append("dictionary_entry[status]", "normal")
    let response = await fetch(this.urlValue, {
      body: formData,
      method: 'PATCH',
      credentials: "include",
      dataType: "script",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
    })
    if (response.ok) {
      this.element.parentNode.removeChild(this.element);
    }
  }

  async ceist(e) {
    let status = "ceist";
    e.preventDefault()
    let formData = new FormData()
    formData.append("dictionary_entry[status]", status)
    let response = await fetch(`/dictionary_entries/${this.idValue}`, {
      body: formData,
      method: 'PATCH',
      credentials: "include",
      dataType: "script",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
    })
    if (response.ok) {
      this.statusTarget.innerText = status;
      this.statusTarget.parentNode.classList.remove('invisible');
    }
  }

  async foghraíocht(e) {
    e.preventDefault()
    let status = "foghraíocht";
    let formData = new FormData()
    formData.append("dictionary_entry[status]", status)
    let response = await fetch(`/dictionary_entries/${this.idValue}`, {
      body: formData,
      method: 'PATCH',
      credentials: "include",
      dataType: "script",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
    })
    if (response.ok) {
      this.statusTarget.innerText = status;
      this.statusTarget.parentNode.classList.remove('invisible');
    }
  }

  async scrios(e) {
    e.preventDefault()
    const rangId = location.pathname.split('/')[2];
    let response = await fetch(`/rangs/${rangId}/dictionary_entries/${this.idValue}`, {
      method: 'DELETE',
      credentials: "include",
      dataType: "script",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
    })
    if (response.ok) {
      this.element.parentNode.removeChild(this.element);
    }
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
