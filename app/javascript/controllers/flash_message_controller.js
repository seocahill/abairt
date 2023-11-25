// app/javascript/controllers/flash_message_controller.js

import { Controller } from "@hotwired/stimulus"
export default class extends Controller {
  connect() {
    // Automatically close flash messages after 5 seconds (5000 milliseconds)
    setTimeout(() => {
      this.element.style.display = "none";
    }, 5000); // Adjust the delay as needed
  }
}
