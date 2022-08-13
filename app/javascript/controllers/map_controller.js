import { Controller } from "@hotwired/stimulus"
import L from 'leaflet'

export default class extends Controller {
  static values = { comhras: Array }


  connect() {
    this.map = L.map('map').setView([53.9110, -9.4527], 9);

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '© OpenStreetMap'
    }).addTo(this.map);

    // debugger
    this.comhrasValue.forEach((comhra) => {
      let marker = L.marker(comhra.lat_lang.split(','))
      let content = `<a href="/comhras/${comhra.id}">${comhra.name}</a><audio controls src="${comhra.media_url}"></audio>`;
      marker.bindPopup(content).openPopup();
      marker.addTo(this.map);
    });

    if (document.getElementById("grupa_lat_lang")) {
      this.map.on('click', (e) => { this.showLatLang(e) });
    }
  }

  showLatLang(e) {
    if (this.marker) {
      this.marker.remove()
    }
    this.marker = L.marker(e.latlng).addTo(this.map);
    document.getElementById("grupa_lat_lang").value = `${e.latlng.lat},${e.latlng.lng}`;
  }
}