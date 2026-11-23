# Pin npm packages by running ./bin/importmap

pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin_all_from "app/javascript/controllers", under: "controllers"
pin "service_worker_registration"

# Third-party modules are served from vendor/javascript, not a CDN (#188). Each
# is a file from the npm package at the version noted, bundled to one ES module:
#   npx esbuild@0.25.12 node_modules/<package>/<entry> --bundle --format=esm --minify --legal-comments=inline --outfile=vendor/javascript/<file>
# Entries: wavesurfer.js dist/wavesurfer.js and dist/plugin/wavesurfer.{regions,timeline}.js,
# @popperjs/core lib/index.js, @tarekraafat/autocomplete.js dist/autoComplete.js,
# leaflet dist/leaflet-src.js, leaflet.markercluster dist/leaflet.markercluster-src.js,
# feather-icons dist/feather.js, recordrtc RecordRTC.js.
pin "wavesurfer.js", to: "wavesurfer.js" # @6.2.0
pin "wavesurfer.js/dist/plugin/wavesurfer.regions.js", to: "wavesurfer.regions.js" # @6.2.0
pin "wavesurfer.js/dist/plugin/wavesurfer.timeline.js", to: "wavesurfer.timeline.js" # @6.2.0
pin "@rails/activestorage", to: "activestorage.esm.js"
pin "jitsi" # @2.1.5
pin "@popperjs/core", to: "popper.js" # @2.11.8
pin "@tarekraafat/autocomplete.js", to: "autocomplete.js" # @10.2.6
pin "leaflet" # @1.8.0
pin "leaflet.markercluster" # @1.5.3
pin "feather-icons" # @4.29.0
pin "trix"
pin "@rails/actiontext", to: "actiontext.js"
pin "recordrtc" # @5.6.2
