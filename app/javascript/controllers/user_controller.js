import { Controller } from "@hotwired/stimulus"
import autoComplete from "autocomplete";

export default class extends Controller {
  static targets = ["userSearch"]

  initialize() {
    console.log("connect to users");
  }

  userSearchTargetConnected() {
    const tagsSearch = new autoComplete({
      selector: "#autoCompleteUsers",
      placeHolder: "Déan cuardach ar user...",
      debounce: 300,
      data: {
        src: async (query) => {
          try {
            // Fetch Data from external Source
            const source = await fetch(`/users?search=${query.replace(/\W/g, '')}`, { headers: { accept: "application/json" } });
            // Data is array of `Objects` | `Strings`
            const data = await source.json();

            return data;
          } catch (error) {
            console.error(error)
            return error;
          }
        },
        keys: ['name']
      },
      resultItem: {
        highlight: {
          render: true
        }
      },
      events: {
        input: {
          selection: (event) => {
            const selection = event.detail.selection.value['name'];
            tagsSearch.input.value = selection;
          }
        }
      }
    })
  }

  format(n) {
    let mil_s = String(n % 1000).padStart(3, '0');
    n = Math.trunc(n / 1000);
    let sec_s = String(n % 60).padStart(2, '0');
    n = Math.trunc(n / 60);
    return String(n) + ' m ' + sec_s + ' s ' + mil_s + ' ms';
  }

  teardown() {
    console.log('good luck!')
  }
}