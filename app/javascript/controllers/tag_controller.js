import { Controller } from "@hotwired/stimulus"
import autoComplete from "autocomplete";

export default class extends Controller {
  static targets = ["cell", "dropdown", "time", "tagSearch"]

  initialize() {
    console.log("connect to tags");
  }

  tagSearchTargetConnected() {
    const selectedTags = [];
    const id = `#${this.element.getElementsByTagName("textarea")[0].id}`
    const tagsSearch = new autoComplete({
      selector: id,
      placeHolder: "Separate each tag with a comma",
      debounce: 300,
      searchEngine: function (query, record) {
        return record
      },
      data: {
        src: async (query) => {
          try {
            // Fetch Data from external Source
            const sanitizedQuery = query
              .split(',')
              .map(tag => tag.trim())
              .at(-1)
              .normalize('NFD') // Convert accented characters to their base form
              .replace(/[\u0300-\u036f]/g, '') // Remove combining diacritical marks
              .replace(/[^a-zA-Z0-9]/g, ''); // Remove non-alphanumeric characters
            const source = await fetch(`/tags?search=${sanitizedQuery}`, { headers: { accept: "application/json" } });
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
            const selection = event.detail.selection.value.name;
            selectedTags.push(selection);
            usersSearch.input.value = selectedTags;
          }
        },
      }
    });
  }

  teardown() {
    console.log('good luck!')
  }
}