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
            const selection = event.detail.selection.value;
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
    // Function to update the display of selected users
    this.updateSelectedUsersDisplay = (users) => {
      const selectedUsersContainer = document.getElementById('selectedUsers');
      selectedUsersContainer.innerHTML = ''; // Clear the container

      // Create a new list item for each selected user
      // <input name="voice_recording[conversation][user_id][]" id="voice_recording_conversation_user_id"/>
      users.forEach(user => {
        const li = document.createElement('li');
        li.classList.add('flex', 'justify-between', 'items-center', 'px-3', 'py-2', 'mb-2', 'rounded', 'bg-gray-200');

        // Create a span for the user name
        const span = document.createElement('span');
        span.innerText = user.name;

        // Create a button to remove the user
        const button = document.createElement('button');
        button.classList.add('ml-2', 'px-2', 'py-1', 'rounded', 'bg-red-500', 'text-white', 'hover:bg-red-600', 'focus:outline-none');
        button.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M10 11.414l4.95-4.95a1 1 0 011.414 1.414L11.414 12l4.95 4.95a1 1 0 01-1.414 1.414L10 13.414l-4.95 4.95a1 1 0 01-1.414-1.414L8.586 12 3.636 7.05a1 1 0 011.414-1.414L10 10.586z" clip-rule="evenodd"/></svg>';
        button.addEventListener('click', () => {
          const index = selectedUsers.indexOf(user);
          if (index > -1) {
            selectedUsers.splice(index, 1);
            this.updateSelectedUsersDisplay(selectedUsers);
          }
        });

        // Append the span and button to the list item
        li.appendChild(span);
        li.appendChild(button);

        // Append the list item to the container
        selectedUsersContainer.appendChild(li);
      });

      // update hidden value
      users.forEach((user) => {
        let field = document.createElement('input');
        field.type = "hidden";
        field.name = "voice_recording[user_ids][]";
        field.value = user.id;
        selectedUsersContainer.append(field);
      });
    };

  }


  teardown() {
    console.log('good luck!')
  }
}