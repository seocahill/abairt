import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["name", "dialect", "ability", "address"]

  fill(event) {
    const button = event.currentTarget
    const name = button.dataset.name
    const dialect = button.dataset.dialect
    const nativeSpeaker = button.dataset.nativeSpeaker
    const location = button.dataset.location

    // Find the form (might be on a different controller instance)
    const form = document.querySelector('#create-speaker-form')
    if (!form) return

    const nameField = form.querySelector('[data-speaker-form-filler-target="name"]')
    const dialectField = form.querySelector('[data-speaker-form-filler-target="dialect"]')
    const abilityField = form.querySelector('[data-speaker-form-filler-target="ability"]')
    const addressField = form.querySelector('[data-speaker-form-filler-target="address"]')

    if (nameField && name) {
      nameField.value = name
    }

    if (dialectField && dialect) {
      // Map Location.dialect_region to User.dialect enum
      const dialectMap = {
        "erris": "tuaisceart_mhaigh_eo",
        "achill": "acaill",
        "tourmakeady": "lár_chonnachta",
        "east_mayo": "connacht_ó_thuaidh",
        "other": "canúintí_eile"
      }
      const mappedDialect = dialectMap[dialect] || dialect
      dialectField.value = mappedDialect
    }

    if (abilityField) {
      // Set ability based on native_speaker status, default to C2 (native)
      abilityField.value = "native"  // Default to native
    
    }

    if (addressField && location) {
      addressField.value = location
    }

    // Scroll to form
    form.scrollIntoView({ behavior: 'smooth', block: 'start' })
  }
}
