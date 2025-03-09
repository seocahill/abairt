import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "pagination"]

  connect() {
    console.log("Infinite scroll controller connected")
    this.isLoading = false
    this.currentPage = 1
    this.createIntersectionObserver()
  }

  disconnect() {
    console.log("Infinite scroll controller disconnected")
    if (this.observer) {
      this.observer.disconnect()
    }
  }

  createIntersectionObserver() {
    const options = {
      root: this.element.closest('.overflow-y-auto'), // Use the scrollable container as root
      rootMargin: '200px', // Increased margin for earlier loading
      threshold: 0.1
    }

    this.observer = new IntersectionObserver(entries => {
      entries.forEach(entry => {
        if (entry.isIntersecting && !this.isLoading) {
          console.log("Pagination element is intersecting")
          this.loadMore()
        }
      })
    }, options)

    // Start observing the pagination element
    if (this.hasPaginationTarget) {
      console.log("Starting to observe pagination element")
      this.observer.observe(this.paginationTarget)
      // Make sure pagination is visible
      this.paginationTarget.classList.remove('hidden')
    } else {
      console.warn("No pagination target found")
    }
  }

  loadMore() {
    const nextPage = this.paginationTarget.querySelector("a[rel='next']")
    if (!nextPage) {
      console.log("No more pages to load")
      return
    }

    const url = nextPage.href
    if (this.isLoading || !url) return

    // Extract page number from URL
    const pageMatch = url.match(/[?&]page=(\d+)/)
    if (pageMatch) {
      const nextPageNum = parseInt(pageMatch[1])
      if (nextPageNum <= this.currentPage) {
        console.log("Preventing duplicate page load:", nextPageNum)
        return
      }
      this.currentPage = nextPageNum
    }

    console.log("Loading more entries from:", url)
    this.isLoading = true
    this.observer.unobserve(this.paginationTarget)

    fetch(url, {
      headers: {
        'Accept': 'text/vnd.turbo-stream.html'
      }
    })
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      return response.text()
    })
    .then(html => {
      console.log("Received response, rendering stream")
      Turbo.renderStreamMessage(html)
      this.isLoading = false

      // Wait for Turbo to finish updating the DOM
      requestAnimationFrame(() => {
        // Only re-observe if we still have a pagination element with a next link
        if (this.hasPaginationTarget && this.paginationTarget.querySelector("a[rel='next']")) {
          console.log("Re-observing pagination for next page")
          this.createIntersectionObserver()
        } else {
          console.log("No more pages to load, stopping observation")
        }
      })
    })
    .catch(error => {
      console.error("Error loading more entries:", error)
      this.isLoading = false
      this.currentPage-- // Reset page number on error
      // Re-observe the pagination element in case of error
      if (this.hasPaginationTarget) {
        this.createIntersectionObserver()
      }
    })
  }
}