import { Controller } from "@hotwired/stimulus"
import L from 'leaflet'
import feather from "feather-icons"

export default class extends Controller {
  static values = {
    pins: Array,
    pubs: Array,
    userId: String
  }

  connect() {
    console.log("Map controller connected");
    this.marker = null;
    this.initializeMap();
    this.initializeFeather();
  }

  initializeFeather() {
    feather.replace();
  }

  initializeMap() {
    this.map = L.map('map', { scrollWheelZoom: true }).setView([53.9860, -9.4125], 9);

    this.map.on('popupopen', (e) => {
      const closeButton = e.popup._closeButton;
      if (closeButton) {
        closeButton.addEventListener('click', (event) => {
          event.preventDefault();
        });
      }
    });

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      minZoom: 9,
      attribution: '© OpenStreetMap'
    }).addTo(this.map);

    // If user already has a location, show it on the map
    const latLangInput = document.getElementById("user-lat-lang");
    if (latLangInput && latLangInput.value) {
      const [lat, lng] = latLangInput.value.split(',');
      this.addMarker(L.latLng(parseFloat(lat), parseFloat(lng)));
      this.map.setView([lat, lng], 12);
    }

    // Add click handler to map
    this.map.on('click', (e) => {
      this.addMarker(e.latlng);
    });

    // Fix map display issues when modal opens
    this.map.invalidateSize();

    const icon = new L.Icon({
      iconUrl:
        "https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-green.png",
      shadowUrl:
        "https://cdnjs.cloudflare.com/ajax/libs/leaflet/0.7.7/images/marker-shadow.png",
      iconSize: [25, 41],
      iconAnchor: [12, 41],
      popupAnchor: [1, -34],
      shadowSize: [41, 41]
    });

    this.pinsValue.forEach((user) => {
      if (user.lat_lang && user.lat_lang.trim() !== '') {
        let marker = L.marker(user.lat_lang.split(','))
        let content
        if (user.media_url) {
          content = `<a href="/users/${user.id}">${user.name}</a><audio controls src="${user.media_url}"></audio>`;
        } else if (user.recording_id) {
          content = `<a data-turbo-frame="wave_display" href="/voice_recordings?search=${user.recording_title}">${user.recording_title}</a>`;
        } else {
          content = `<a href="/users/${user.id}">${user.name}</a>`;
        }
        marker.bindPopup(content).openPopup();
        marker.addTo(this.map);
      }
    });

    if (this.hasPubsValue) {
      this.pubsValue.forEach((pub) => {
        let marker = L.marker(pub.lat_lang.split(','), { icon })
        let content = `<a target=”_blank” href="${pub.url}">${pub.name}</a>`;
        marker.bindPopup(content).openPopup();
        marker.addTo(this.map);
      });
    }
  }

  addMarker(latlng) {
    if (this.marker) {
      this.marker.remove();
    }
    this.marker = L.marker(latlng).addTo(this.map);
    document.getElementById("user-lat-lang").value = `${latlng.lat},${latlng.lng}`;
  }

  openModal() {
    document.getElementById('mapModal').classList.remove('hidden');
    // Fix map display issues when modal opens
    setTimeout(() => {
      this.map.invalidateSize();
      // If there's an existing marker, center on it
      if (this.marker) {
        this.map.setView(this.marker.getLatLng(), 12);
      }
    }, 100);
  }

  closeModal() {
    document.getElementById('mapModal').classList.add('hidden');
  }

  saveLocation(event) {
    if (!this.marker) return;

    const latLng = this.marker.getLatLng();

    // Check if we're just populating form fields (for new speaker form)
    const isFormPopulate = event.params && event.params.formOnly;

    if (isFormPopulate) {
      // Just populate the form fields
      fetch(`https://nominatim.openstreetmap.org/reverse?format=json&lat=${latLng.lat}&lon=${latLng.lng}`)
        .then(response => response.json())
        .then(data => {
          document.getElementById("user-lat-lang").value = `${latLng.lat},${latLng.lng}`;
          const addressInput = document.querySelector('input[name*="[address]"]');
          if (addressInput) {
            addressInput.value = data.display_name;
          }
          this.closeModal();
        })
        .catch(error => {
          console.error('Error getting address:', error);
        });
      return;
    }

    // Original update user logic
    const csrfToken = document.querySelector('meta[name="csrf-token"]').getAttribute('content');

    fetch(`https://nominatim.openstreetmap.org/reverse?format=json&lat=${latLng.lat}&lon=${latLng.lng}`)
      .then(response => response.json())
      .then(data => {
        const updateData = {
          partial: "profile",
          user: {
            lat_lang: `${latLng.lat},${latLng.lng}`,
            address: data.display_name
          }
        };

        return fetch(`/users/${this.userIdValue}`, {
          method: 'PATCH',
          headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': csrfToken
          },
          body: JSON.stringify(updateData),
        });
      })
      .then(response => {
        if (response.ok) {
          this.closeModal();
          window.location.reload();
        } else {
          throw new Error('Failed to update location');
        }
      })
      .catch(error => {
        console.error('Error:', error);
      });
  }

  showMap(e) {
    e.preventDefault()
    document.getElementById('users-list').classList.toggle('hidden')
    document.getElementById('map-container').classList.toggle('hidden')
  }
}