import { Controller } from "@hotwired/stimulus"
import L from 'leaflet'

export default class extends Controller {
  static values = { pins: Array }


  connect() {
    this.map = L.map('map', { scrollWheelZoom: false }).setView([53.9860, -9.4125], 9);

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      minZoom: 9,
      attribution: '© OpenStreetMap'
    }).addTo(this.map);

    this.pinsValue.forEach((user) => {
      let marker = L.marker(user.lat_lang.split(','))
      let content
      if (user.media_url) {
        content = `<a href="/users/${user.id}">${user.name}</a><audio controls src="${user.media_url}"></audio>`;
      } else {
        content = `<a href="/users/${user.id}">${user.name}</a>`;
      }
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

  showMap(e) {
    e.preventDefault()
    document.getElementById('users-list').classList.toggle('hidden')
    document.getElementById('map-container').classList.toggle('hidden')
  }
}