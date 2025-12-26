import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    openapiUrl: String,
    apiToken: String
  }

  connect() {
    // Wait for Swagger UI scripts to load (loaded in head via content_for)
    this.waitForSwaggerUI().then(() => this.initSwagger());
  }

  waitForSwaggerUI() {
    return new Promise((resolve) => {
      const checkInterval = setInterval(() => {
        if (typeof window.SwaggerUIBundle !== 'undefined' && typeof window.SwaggerUIStandalonePreset !== 'undefined') {
          clearInterval(checkInterval);
          resolve();
        }
      }, 100);

      // Timeout after 5 seconds
      setTimeout(() => {
        clearInterval(checkInterval);
        if (typeof window.SwaggerUIBundle === 'undefined') {
          console.error('Swagger UI failed to load');
        }
        resolve();
      }, 5000);
    });
  }

  initSwagger() {
    if (typeof window.SwaggerUIBundle === 'undefined' || typeof window.SwaggerUIStandalonePreset === 'undefined') {
      console.error('Swagger UI not loaded');
      return;
    }

    const ui = window.SwaggerUIBundle({
      url: this.openapiUrlValue,
      dom_id: '#swagger-ui',
      presets: [
        window.SwaggerUIBundle.presets.apis,
        window.SwaggerUIStandalonePreset
      ],
      layout: "StandaloneLayout",
      deepLinking: true,
      tryItOutEnabled: true,
      filter: false,
      docExpansion: "list",
      defaultModelsExpandDepth: 1,
      defaultModelExpandDepth: 1,
      requestInterceptor: (request) => {
        if (this.apiTokenValue) {
          request.headers['Authorization'] = `Bearer ${this.apiTokenValue}`;
        }
        return request;
      }
    });
  }

  copyToken(event) {
    const tokenElement = document.getElementById('api-token');
    if (tokenElement) {
      const token = tokenElement.textContent.trim();
      navigator.clipboard.writeText(token).then(() => {
        alert('Token copied to clipboard!');
      }).catch(err => {
        console.error('Failed to copy token:', err);
      });
    }
  }
}

