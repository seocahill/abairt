import { Controller } from "@hotwired/stimulus"
import L from 'leaflet'
import feather from "feather-icons"

// Expose L globally so leaflet.markercluster plugin can extend it
window.L = L

// Load the markercluster plugin once, after L is global (it extends window.L).
// A failed load falls back to plain markers.
const markerClusterReady = import("leaflet.markercluster").catch(() => {})

export default class extends Controller {
  static targets = ["desktopContainer", "modalContainer", "modal"]
  static values = {
    pins: Array,
    pubs: Array,
    userId: { type: String, default: '' },
    // Open centred on the pins (a place page) instead of the whole of Mayo.
    focus: Boolean
  }

  connect() {
    console.log("Map controller connected");
    this.marker = null;

    // Wait for markercluster to load, then initialize map
    markerClusterReady.then(() => {
      if (this.hasDesktopContainerTarget) {
        this.initializeMap(this.desktopContainerTarget);
      } else if (this.element.id === "map") {
        this.initializeMap(this.element);
      }
    });

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

    // Use marker clustering if available, fall back to direct map addition
    const clusterGroup = (typeof L.markerClusterGroup === 'function')
      ? L.markerClusterGroup({ maxClusterRadius: 50, spiderfyOnMaxZoom: true, showCoverageOnHover: false })
      : null;

    this.pinsValue.forEach((pin) => {
      let marker;
      let content;

      if (pin.recordings && pin.lat && pin.lng) {
        // One pin per place (f172_place_pages): see PlacePins.
        marker = L.marker([pin.lat, pin.lng]);
        content = this.placePopup(pin);
      } else if (pin.lat && pin.lng) {
        marker = L.marker([pin.lat, pin.lng]);
        content = `
          <div class="text-center">
            <strong>${pin.location_id ? `<a href="/locations/${pin.location_id}">${this.escape(pin.location_name)}</a>` : this.escape(pin.location_name || '')}</strong><br>
            <a href="/voice_recordings/${pin.recording_id}">${this.escape(pin.recording_title || '')}</a>
          </div>
        `;
      } else if (pin.lat_lang && pin.lat_lang.trim() !== '') {
        // Legacy format support (users page)
        marker = L.marker(pin.lat_lang.split(','));
        if (pin.media_url) {
          content = `<a href="/users/${pin.id}">${this.escape(pin.name || '')}</a><audio controls src="${pin.media_url}"></audio>`;
        } else if (pin.recording_id) {
          content = `<a href="/voice_recordings/${pin.recording_id}">${this.escape(pin.recording_title || '')}</a>`;
        } else {
          content = `<a href="/users/${pin.id}">${this.escape(pin.name || '')}</a>`;
        }
      }

      if (marker && content) {
        // A place popup is tall; keep it clear of the zoom buttons when it opens.
        marker.bindPopup(content, pin.recordings ? { autoPanPaddingTopLeft: [56, 16] } : {});
        if (clusterGroup) {
          clusterGroup.addLayer(marker);
        } else {
          marker.addTo(this.map);
        }
      }
    });

    if (clusterGroup) {
      this.map.addLayer(clusterGroup);
    }

    if (this.focusValue) this.focusOnPins();

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

  focusOnPins() {
    const points = this.pinsValue.filter((pin) => pin.lat && pin.lng).map((pin) => [pin.lat, pin.lng]);
    if (points.length === 1) {
      this.map.setView(points[0], 12);
    } else if (points.length > 1) {
      this.map.fitBounds(points, { padding: [24, 24], maxZoom: 12 });
    }
  }

  // A place's name, a button to its page, then its recordings spaced apart so
  // a tap lands on the one meant. Pins with no mapped place are drawn at a speaker's
  // location and say so rather than showing the speaker's name as the place.
  placePopup(pin) {
    const heading = pin.location_name
      ? `<div class="text-sm font-semibold text-gray-900">${this.escape(pin.location_name)}</div>`
      : `<div class="text-sm font-semibold text-gray-500">Place not on the map</div>
         <div class="text-xs text-gray-500">Shown at the speaker's location</div>`;
    const button = pin.location_id
      ? `<a href="/locations/${pin.location_id}" class="mt-2 inline-flex items-center px-4 py-2 border border-gray-300 shadow-xs text-sm font-medium rounded-md text-gray-700! bg-white hover:bg-gray-50 focus:outline-hidden focus:ring-2 focus:ring-offset-2 focus:ring-blue-500">Open place page</a>`
      : '';
    const items = pin.recordings.map((recording) =>
      `<li><a href="/voice_recordings/${recording.id}" class="block py-2 text-sm text-indigo-700! hover:text-indigo-900!">${this.escape(recording.title)}</a></li>`
    ).join('');
    const list = items ? `<ul class="mt-3 border-t border-gray-100 divide-y divide-gray-100">${items}</ul>` : '';
    const moreText = `and ${pin.more} more`;
    const more = pin.more > 0
      ? `<div class="pt-2 text-xs text-gray-500">${pin.location_id ? `<a href="/locations/${pin.location_id}" class="text-gray-500! underline">${moreText}</a>` : moreText}</div>`
      : '';
    return `<div class="w-56">${heading}${button}${list}${more}</div>`;
  }

  escape(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
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
    if (!this.hasModalTarget || !this.hasModalContainerTarget) return;

    this.modalTarget.classList.remove("hidden")
    document.body.style.overflow = "hidden"

    // Ensure the modal container is visible and has dimensions
    this.modalContainerTarget.style.width = '100%'
    this.modalContainerTarget.style.height = '600px'
    this.modalContainerTarget.style.display = 'block'

    // Wait for the modal to be fully rendered before initializing map
    setTimeout(() => {
      this.initializeMap(this.modalContainerTarget)
      
      // Force another resize after map initialization
      setTimeout(() => {
        if (this.map) {
          this.map.invalidateSize()
        }
      }, 100)
    }, 50)

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
    if (!this.hasModalTarget) return;

    this.modalTarget.classList.add("hidden")
    document.body.style.overflow = ""

    // Clean up the map
    if (this.map) {
      this.map.remove()
      this.map = null
    }

    // Reinitialize map in desktop container if on desktop
    if (window.innerWidth >= 768 && this.hasDesktopContainerTarget) {
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