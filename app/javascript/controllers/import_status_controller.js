import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { 
    url: String,
    status: String,
    interval: { type: Number, default: 3000 } // 3 seconds
  }
  
  connect() {
    // Only start polling if import is in progress
    if (this.statusValue === 'pending' || this.statusValue === 'processing') {
      console.log('Starting import status polling...')
      this.startPolling()
    }
  }
  
  disconnect() {
    this.stopPolling()
  }
  
  startPolling() {
    if (this.pollTimer) {
      return // Already polling
    }
    
    this.pollTimer = setInterval(() => {
      this.checkStatus()
    }, this.intervalValue)
  }
  
  stopPolling() {
    if (this.pollTimer) {
      clearInterval(this.pollTimer)
      this.pollTimer = null
      console.log('Stopped import status polling')
    }
  }
  
  async checkStatus() {
    try {
      const response = await fetch(this.urlValue, {
        headers: {
          'Accept': 'application/json'
        }
      })
      
      if (!response.ok) {
        throw new Error('Failed to fetch status')
      }
      
      const data = await response.json()
      console.log('Import status:', data)
      
      // If status changed to completed or failed, reload the page
      if (data.status === 'completed' || data.status === 'failed') {
        this.stopPolling()
        console.log('Import finished, reloading page...')
        
        // Add a small delay to ensure backend processing is complete
        setTimeout(() => {
          window.location.reload()
        }, 1000)
      }
      
      // Update the current status for next check
      this.statusValue = data.status
      
    } catch (error) {
      console.error('Error checking import status:', error)
      // Stop polling on error to avoid spamming the server
      this.stopPolling()
    }
  }
}