// app/javascript/controllers/tabbed_sidebar_controller.js
import { Controller } from "@hotwired/stimulus"
import feather from "feather-icons"

export default class extends Controller {
  static targets = ["content"]

  connect() {
    feather.replace()
  }

  showTab(event) {
    event.preventDefault()
    const tabName = event.params.tab

    const tabButtons = document.querySelectorAll('.tab-button');
    tabButtons.forEach(tabButton => {
      if (tabButton.dataset.sidebarTabParam === tabName) {
        tabButton.classList.add('active');
      } else {
        tabButton.classList.remove('active');
      }
    });
    const tabPanes = document.querySelectorAll('.tab-pane');
    tabPanes.forEach(tabPane => {
      if (tabPane.id === tabName) {
        tabPane.classList.remove('hidden');
      } else {
        tabPane.classList.add('hidden');
      }
    });
  }
}
