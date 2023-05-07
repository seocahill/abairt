import { Controller } from "@hotwired/stimulus"
import L from 'leaflet'

export default class extends Controller {
  static values = { pins: Array }

  connect() {
    console.log("hello map")
    this.map = L.map('map').setView([53.9110, -9.4527], 9);

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      minZoom: 9,
      attribution: '© OpenStreetMap'
    }).addTo(this.map);

    // this.pinsValue.forEach((rang) => {
    //   let marker = L.marker(rang.lat_lang.split(','))
    //   let content = `<a href="/grupas/${rang.id}">${rang.ainm}</a><audio controls src="${rang.media_url}"></audio>`;
    //   marker.bindPopup(content).openPopup();
    //   marker.addTo(this.map);
    // });

    // if (document.getElementById("grupa_lat_lang")) {
    //   this.map.on('click', (e) => { this.showLatLang(e) });
    // }
  }

  showLatLang(e) {
    if (this.marker) {
      this.marker.remove()
    }
    this.marker = L.marker(e.latlng).addTo(this.map);
    document.getElementById("grupa_lat_lang").value = `${e.latlng.lat},${e.latlng.lng}`;
  }
}