// import Rails from "@rails/ujs";
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  onPostSuccess(event) {
    console.log("success!");
  }

  update() {
    // Rails.fire(this.element, 'submit');
  }
}
