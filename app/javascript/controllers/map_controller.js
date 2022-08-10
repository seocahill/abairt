import { Controller } from "@hotwired/stimulus"
import L from 'leaflet'


export default class extends Controller {
  connect() {
    let map = L.map('map').setView([53.9110, -9.4527], 9);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '© OpenStreetMap'
    }).addTo(map);
    let marker = L.marker([53.91, -9.4527]).addTo(map);
    map.on('click', (e) => { L.popup().setLatLng(e.latlng).setContent("You clicked the map at " + e.latlng.toString()).openOn(map); });
  }
}