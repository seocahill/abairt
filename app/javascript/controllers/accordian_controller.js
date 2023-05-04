// app/javascript/controllers/tabbed_sidebar_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {

  showHide(event) {
    event.preventDefault()
    const pane = document.querySelector(event.params.pane)
    pane.classList.toggle('max-h-0');
  }
}
