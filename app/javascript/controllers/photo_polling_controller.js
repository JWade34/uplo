import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { 
    url: String,
    interval: { type: Number, default: 3000 }
  }

  connect() {
    if (this.element.dataset.processing === "true") {
      this.startPolling()
    }
  }

  disconnect() {
    this.stopPolling()
  }

  startPolling() {
    this.poll()
    this.timer = setInterval(() => {
      this.poll()
    }, this.intervalValue)
  }

  stopPolling() {
    if (this.timer) {
      clearInterval(this.timer)
    }
  }

  async poll() {
    try {
      const response = await fetch(this.urlValue, {
        headers: {
          "Accept": "text/vnd.turbo-stream.html",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        }
      })
      
      if (response.ok) {
        const text = await response.text()
        // Check if we received a signal to stop polling
        if (text.includes('data-processing="false"')) {
          this.stopPolling()
          // Reload the page to show the generated captions
          window.location.reload()
        }
      }
    } catch (error) {
      console.error("Polling error:", error)
    }
  }
}