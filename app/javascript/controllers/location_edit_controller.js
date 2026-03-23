import { Controller } from "@hotwired/stimulus"
import L from "leaflet"

export default class extends Controller {
  static targets = ["map", "latitude", "longitude"]
  static values = {
    lat: { type: Number, default: 53.9 },
    lng: { type: Number, default: -9.5 },
    hasCoords: { type: Boolean, default: false }
  }

  connect() {
    this.initializeMap()
  }

  disconnect() {
    if (this.map) {
      this.map.remove()
      this.map = null
    }
  }

  initializeMap() {
    const zoom = this.hasCoordsValue ? 13 : 9
    this.map = L.map(this.mapTarget, { scrollWheelZoom: true })
      .setView([this.latValue, this.lngValue], zoom)

    L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution: "&copy; OpenStreetMap contributors"
    }).addTo(this.map)

    if (this.hasCoordsValue) {
      this.marker = L.marker([this.latValue, this.lngValue]).addTo(this.map)
    }

    this.map.on("click", (e) => this.placeMarker(e.latlng))

    // Fix tile rendering in hidden/late-loading containers
    setTimeout(() => this.map.invalidateSize(), 100)
  }

  placeMarker(latlng) {
    if (this.marker) {
      this.marker.setLatLng(latlng)
    } else {
      this.marker = L.marker(latlng).addTo(this.map)
    }

    // Update form fields — they may be in a sibling controller scope,
    // so find them by ID as a fallback
    const latField = this.hasLatitudeTarget
      ? this.latitudeTarget
      : document.getElementById("location-latitude")
    const lngField = this.hasLongitudeTarget
      ? this.longitudeTarget
      : document.getElementById("location-longitude")

    if (latField) latField.value = latlng.lat.toFixed(6)
    if (lngField) lngField.value = latlng.lng.toFixed(6)
  }
}
