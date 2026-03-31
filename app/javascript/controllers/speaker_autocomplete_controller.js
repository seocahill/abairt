import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results", "hiddenField"]
  static values = { url: String }

  connect() {
    this.timeout = null
    this.selected = false
  }

  search() {
    clearTimeout(this.timeout)
    this.selected = false

    const query = this.inputTarget.value.trim()

    if (query.length < 2) {
      this.hideResults()
      return
    }

    this.timeout = setTimeout(() => {
      fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`)
        .then(response => response.json())
        .then(data => this.displayResults(data))
    }, 300)
  }

  displayResults(speakers) {
    if (speakers.length === 0) {
      this.hideResults()
      return
    }

    this.resultsTarget.innerHTML = speakers.map(speaker => `
      <div class="px-4 py-2 hover:bg-gray-100 cursor-pointer border-b last:border-b-0"
           data-speaker-id="${speaker.id}"
           data-action="click->speaker-autocomplete#select">
        <div class="font-medium">${speaker.name}</div>
        <div class="text-sm text-gray-600">${speaker.dialect?.humanize() || ''} - ${speaker.ability?.humanize() || ''}</div>
      </div>
    `).join('')

    this.resultsTarget.classList.remove('hidden')
  }

  select(event) {
    const speakerId = event.currentTarget.dataset.speakerId
    const speakerName = event.currentTarget.querySelector('.font-medium').textContent

    this.inputTarget.value = speakerName
    this.hiddenFieldTarget.value = speakerId
    this.selected = true
    this.hideResults()
  }

  hideResults() {
    this.resultsTarget.classList.add('hidden')
  }

  blur() {
    // Delay to allow click event to fire
    setTimeout(() => {
      if (!this.selected) {
        this.hiddenFieldTarget.value = ''
      }
      this.hideResults()
    }, 200)
  }

  quickSearch(event) {
    const query = event.currentTarget.dataset.query
    this.inputTarget.value = query
    this.inputTarget.focus()
    this.search()
  }
}

// Simple humanize helper
String.prototype.humanize = function() {
  return this.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())
}
