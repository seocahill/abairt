import { Controller } from "@hotwired/stimulus"
import { createPopper } from "popper"

export default class extends Controller {
  static targets = ["word", "template"]

  focloir(e) {
    e.preventDefault()

    if (document.querySelector('#tooltip')) {
      document.querySelector('#tooltip').remove()
    }

    this.wordTarget.appendChild(this.templateTarget.content.cloneNode(true));
    const button = this.wordTarget
    const tooltip = document.querySelector('#tooltip');

    createPopper(button, tooltip, {
      modifiers: [
        {
          name: 'offset',
          options: {
            offset: [0, 8],
          },
        },
      ],
    });
  }

  dun(e) {
    e.stopImmediatePropagation()
    document.querySelector('#tooltip').remove()
  }
}
