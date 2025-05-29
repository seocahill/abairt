// app/javascript/controllers/flash_message_controller.js

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Automatically close flash messages after 5 seconds (5000 milliseconds)
    setTimeout(() => {
      this.fadeOut();
    }, 5000); // Adjust the delay as needed
  }

  dismiss(event) {
    event.preventDefault();
    this.fadeOut();
  }

  fadeOut() {
    // Add fade-out animation class
    this.element.classList.add('opacity-0');
    this.element.style.transition = 'opacity 0.5s ease';

    // Remove the element after animation completes
    setTimeout(() => {
      this.element.remove();
    }, 500);
  }
}
