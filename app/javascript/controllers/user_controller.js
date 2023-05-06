import { Controller } from "@hotwired/stimulus"
import autoComplete from "autocomplete";

export default class extends Controller {
  static targets = ["userSearch"]

  initialize() {
    console.log("connect to users");
  }

  userSearchTargetConnected() {
    const selectedUsers = []; // array to hold selected users
    const usersSearch = new autoComplete({
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
            usersSearch.input.value = selection;
            selectedUsers.push(selection);
            this.updateSelectedUsersDisplay(selectedUsers);
            if (!usersSearch.options.multiple) {
              usersSearch.input.value = '';
            }
          }
        },
      }
    });

    // Function to update the display of selected users
    this.updateSelectedUsersDisplay = (users) => {
      const selectedUsersContainer = document.getElementById('selectedUsers');
      selectedUsersContainer.innerHTML = ''; // Clear the container

      // Create a new list item for each selected user
      users.forEach(user => {
        const li = document.createElement('li');
        li.innerText = user;
        selectedUsersContainer.appendChild(li);
      });
    };
  }


  teardown() {
    console.log('good luck!')
  }
}