import { Controller } from "@hotwired/stimulus"
import L from 'leaflet'
import feather from "feather-icons"

export default class extends Controller {
  static targets = ["desktopContainer", "modalContainer", "modal"]
  static values = {
    pins: Array,
    pubs: Array,
    userId: { type: String, default: '' }
  }

  connect() {
    console.log("Map controller connected");
    this.marker = null;
    this.initializeMap(this.desktopContainerTarget);
    this.initializeFeather();
  }

  disconnect() {
    if (this.map) {
      this.map.remove()
      this.map = null
    }
  }

  initializeFeather() {
    feather.replace();
  }

  initializeMap(container) {
    if (this.map) {
      this.map.remove()
      this.map = null
    }

    this.map = L.map(container, {
      scrollWheelZoom: true
    }).setView([53.9860, -9.4125], 9)

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '© OpenStreetMap contributors'
    }).addTo(this.map)

    // Only try to get lat-lang input if we're in user profile mode
    if (this.hasUserIdValue) {
      const latLangInput = document.getElementById("user-lat-lang");
      if (latLangInput && latLangInput.value) {
        const [lat, lng] = latLangInput.value.split(',');
        this.addMarker(L.latLng(parseFloat(lat), parseFloat(lng)));
        this.map.setView([lat, lng], 12);
      }

      // Add click handler to map only in user profile mode
      this.map.on('click', (e) => {
        this.addMarker(e.latlng);
      });
    }

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
        let content = `<a target="_blank" href="${pub.url}">${pub.name}</a>`;
        marker.bindPopup(content).openPopup();
        marker.addTo(this.map);
      });
    }

    // Fix map display issues
    this.map.invalidateSize()
  }

  addMarker(latlng) {
    if (this.marker) {
      this.marker.remove();
    }
    this.marker = L.marker(latlng).addTo(this.map);
    const latLangInput = document.getElementById("user-lat-lang");
    if (latLangInput) {
      latLangInput.value = `${latlng.lat},${latlng.lng}`;
    }
  }

  openModal() {
    this.modalTarget.classList.remove("hidden")
    document.body.style.overflow = "hidden"

    // Ensure the modal container is visible and has dimensions
    this.modalContainerTarget.style.width = '100%'
    this.modalContainerTarget.style.height = '100%'

    // Initialize map in modal
    this.initializeMap(this.modalContainerTarget)

    // Force a resize after a short delay to ensure proper rendering
    setTimeout(() => {
      this.map.invalidateSize()
    }, 100)

    // Add escape key handler
    this.escapeHandler = (e) => {
      if (e.key === "Escape") this.closeModal()
    }
    document.addEventListener("keydown", this.escapeHandler)

    // Add click outside handler
    this.clickOutsideHandler = (e) => {
      if (e.target === this.modalTarget) this.closeModal()
    }
    document.addEventListener("click", this.clickOutsideHandler)
  }

  closeModal() {
    this.modalTarget.classList.add("hidden")
    document.body.style.overflow = ""

    // Clean up the map
    if (this.map) {
      this.map.remove()
      this.map = null
    }

    // Reinitialize map in desktop container if on desktop
    if (window.innerWidth >= 768) {
      this.initializeMap(this.desktopContainerTarget)
    }

    // Remove event listeners
    document.removeEventListener("keydown", this.escapeHandler)
    document.removeEventListener("click", this.clickOutsideHandler)
  }

  saveLocation(event) {
    if (!this.hasUserIdValue || !this.marker) return;

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