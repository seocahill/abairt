# Pin npm packages by running ./bin/importmap

pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin_all_from "app/javascript/controllers", under: "controllers"
pin "service_worker_registration"

# Third-party modules are served from vendor/javascript, not a CDN (#188). Each
# is the npm package's file at the version noted, bundled to one ES module:
#   npx esbuild <package file> --bundle --format=esm --minify --legal-comments=inline --outfile=vendor/javascript/<name>.js
pin "wavesurferjs", to: "wavesurfer.js" # @6.2.0
pin "wavesurferregionsjs", to: "wavesurfer.regions.js" # @6.2.0
pin "wavesurfertimelinejs", to: "wavesurfer.timeline.js" # @6.2.0
pin "@rails/activestorage", to: "activestorage.esm.js"
pin "jitsi" # @2.1.5
pin "popper" # @popperjs/core@2.11.8
pin "autocomplete" # @tarekraafat/autocomplete.js@10.2.6
pin "leaflet" # @1.8.0
pin "leaflet.markercluster" # @1.5.3
pin "feather-icons" # @4.29.0
pin "trix"
pin "@rails/actiontext", to: "actiontext.js"
pin "recordrtc" # @5.6.2
