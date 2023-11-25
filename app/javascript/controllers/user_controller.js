import { Controller } from "@hotwired/stimulus"
import autoComplete from "autocomplete";

export default class extends Controller {
  static targets = ["userSearch"]
  static values = { "fieldName": String }

  initialize() {
    console.log("connect to users");
  }

  userSearchTargetConnected() {
    const fieldName = this.fieldNameValue || "rang[user_ids][]"
    const selectedUsers = []; // array to hold selected users
    const usersSearch = new autoComplete({
      selector: "#autoCompleteUsers",
      placeHolder: "Déan cuardach ar user...",
      debounce: 300,
      searchEngine: function (query, record) {
        return record
      },
      data: {
        src: async (query) => {
          try {
            // Fetch Data from external Source
            const sanitizedQuery = query.normalize('NFD') // Convert accented characters to their base form
              .replace(/[\u0300-\u036f]/g, '') // Remove combining diacritical marks
              .replace(/[^a-zA-Z0-9]/g, ''); // Remove non-alphanumeric characters
            const source = await fetch(`/users?search=${sanitizedQuery}`, { headers: { accept: "application/json" } });
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
            const form = event.target.closest('form');
            usersSearch.input.value = event.detail.selection.value.name;
            const userIdInput = document.createElement("input");
            userIdInput.type = "hidden";
            userIdInput.name = fieldName;
            userIdInput.value = event.detail.selection.value.id;

            // Append the hidden input to the form
            form.appendChild(userIdInput);
            form.requestSubmit()
          }
        },
      }
    });
  }


  teardown() {
    console.log('good luck!')
  }
}