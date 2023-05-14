import { Controller } from "@hotwired/stimulus"
import autoComplete from "autocomplete";

export default class extends Controller {
  static targets = ["cell", "dropdown", "time", "wordSearch", "tagSearch"]

  initialize() {
    console.log("connect to tags");
  }

  wordSearchTargetConnected() {
    const abairtSearch = new autoComplete({
      selector: "#autoComplete",
      placeHolder: "Déan cuardach ar focal...",
      debounce: 300,
      threshold: 2,
      data: {
        src: async (query) => {
          try {
            // Fetch Data from external Source
            const source = await fetch(`/dictionary_entries?search=${query.replace(/\W/g, '')}`, { headers: { accept: "application/json" } });
            // Data is array of `Objects` | `Strings`
            const data = await source.json();

            return data;
          } catch (error) {
            return error;
          }
        },
        keys: ['word_or_phrase']
      },
      resultItem: {
        highlight: {
          render: true
        }
      },
      events: {
        input: {
          selection: (event) => {
            console.log
            document.getElementById("dictionary_entry_id").value = event.detail.selection.value["id"]
            abairtSearch.input.value = event.detail.selection.value["word_or_phrase"]
            document.getElementById("translation").value = event.detail.selection.value["translation"]
            document.getElementById("notes").value = event.detail.selection.value["notes"]
            document.getElementById("autoCompleteTags").value = event.detail.selection.value["tag_list"]
          }
        }
      }
    })
  }

  tagSearchTargetConnected() {
    const tagsSearch = new autoComplete({
      selector: "#autoCompleteTags",
      placeHolder: "Déan cuardach ar clib...",
      debounce: 300,
      data: {
        src: async (query) => {
          try {
            // Fetch Data from external Source
            const source = await fetch(`/tags?search=${query.replace(/\W/g, '')}`, { headers: { accept: "application/json" } });
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