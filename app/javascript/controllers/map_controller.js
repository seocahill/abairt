import { Controller } from "@hotwired/stimulus"
import L from 'leaflet'

export default class extends Controller {
  connect() {
    this.map = L.map('map').setView([53.9110, -9.4527], 9);

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '© OpenStreetMap'
    }).addTo(this.map);

    // let marker = L.marker([53.91, -9.4527]).addTo(map);
    this.map.on('click', (e) => { this.showLatLang(e) });
  }

  showLatLang(e) {
    if (this.marker) {
      this.marker.remove()
    }
    this.marker = L.marker(e.latlng).addTo(this.map);
    document.getElementById("comhra_lat_lang").value = `${e.latlng.lat},${e.latlng.lng}`;
  }
}