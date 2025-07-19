import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Listen for Turbo Frame loads to update URL
    this.element.addEventListener('turbo:frame-load', this.updateUrlAfterLoad.bind(this))
  }

  disconnect() {
    this.element.removeEventListener('turbo:frame-load', this.updateUrlAfterLoad.bind(this))
  }

  updateUrl(event) {
    // Store the page info for when the frame loads
    const link = event.currentTarget
    this.pendingPage = link.dataset.paginationPageValue
  }

  updateUrlAfterLoad(event) {
    // Update URL after Turbo Frame content loads
    if (this.pendingPage) {
      const url = new URL(window.location)
      url.searchParams.set('page', this.pendingPage)
      
      // Update the browser URL without triggering a page reload
      window.history.replaceState({}, '', url.toString())
      
      // Clear pending value
      this.pendingPage = null
    }
  }
} 