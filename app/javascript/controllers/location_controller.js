import { Controller } from "@hotwired/stimulus"
import autoComplete from "autocomplete";

export default class extends Controller {
  static targets = ["locationSearch"]

  initialize() {
    console.log("connect to location search");
  }

  locationSearchTargetConnected() {
    const id = `#${this.element.getElementsByTagName("textarea")[0].id}`
    const locSearch = new autoComplete({
      selector: id,
      placeHolder: "Déan cuardach ar áit...",
      debounce: 300,
      threshold: 3,
      searchEngine: function (query, record) {
        return record
      },
      data: {
        src: async (query) => {
          try {
            // Fetch Data from external Source
            var url = 'https://nominatim.openstreetmap.org/search?q=' + encodeURIComponent(query) + '&format=json&limit=20&countrycodes=ie';
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