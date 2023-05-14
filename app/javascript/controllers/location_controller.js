import { Controller } from "@hotwired/stimulus"
import autoComplete from "autocomplete";

export default class extends Controller {
  static targets = ["locationSearch"]

  initialize() {
    console.log("connect to location search");
  }

  locationSearchTargetConnected() {
    const locSearch = new autoComplete({
      selector: "#autoCompleteLocation",
      placeHolder: "Déan cuardach ar áit...",
      debounce: 300,
      threshold: 2,
      data: {
        src: async (query) => {
          try {
            // Fetch Data from external Source
            var url = 'https://nominatim.openstreetmap.org/search?q=' + encodeURIComponent(query) + '&format=json&limit=10';
            const source = await fetch(url, { headers: { accept: "application/json" } });
            // Data is array of `Objects` | `Strings`
            const data = await source.json();
            return data;
          } catch (error) {
            return error;
          }
        },
        keys: ['display_name']
      },
      resultItem: {
        highlight: {
          render: true
        }
      },
      events: {
        input: {
          selection: (event) => {
            locSearch.input.value = event.detail.selection.value.display_name
            document.getElementById("user-lat-lang").value = event.detail.selection.value.lat + "," + event.detail.selection.value.lon
          }
        }
      }
    })
  }

  teardown() {
    console.log('good luck!')
  }
}