import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["slide", "dot", "container"]
  
  connect() {
    this.currentSlide = 0
    this.slideCount = this.slideTargets.length
    this.startAutoplay()
  }

  disconnect() {
    this.stopAutoplay()
  }

  startAutoplay() {
    this.autoplayInterval = setInterval(() => {
      this.nextSlide()
    }, 4000) // Change slide every 4 seconds
  }

  stopAutoplay() {
    if (this.autoplayInterval) {
      clearInterval(this.autoplayInterval)
    }
  }

  nextSlide() {
    this.currentSlide = (this.currentSlide + 1) % this.slideCount
    this.updateSlides()
  }

  goToSlide(event) {
    this.stopAutoplay() // Stop autoplay when user manually navigates
    this.currentSlide = parseInt(event.currentTarget.dataset.index)
    this.updateSlides()
    
    // Restart autoplay after 10 seconds
    setTimeout(() => {
      this.startAutoplay()
    }, 10000)
  }

  updateSlides() {
    this.slideTargets.forEach((slide, index) => {
      const offset = (index - this.currentSlide) * 100
      slide.style.transform = `translateX(${offset}%)`
    })

    // Update dots
    this.dotTargets.forEach((dot, index) => {
      if (index === this.currentSlide) {
        dot.classList.remove("bg-gray-400")
        dot.classList.add("bg-accent")
      } else {
        dot.classList.remove("bg-accent")
        dot.classList.add("bg-gray-400")
      }
    })
  }
}