# Pin npm packages by running ./bin/importmap

pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin_all_from "app/javascript/controllers", under: "controllers"

pin "process", to: "https://ga.jspm.io/npm:@jspm/core@2.0.0-beta.12/nodelibs/browser/process-production.js"
pin "util", to: "https://ga.jspm.io/npm:@jspm/core@2.0.0-beta.12/nodelibs/browser/util.js"
pin "wavesurferjs", to: "https://ga.jspm.io/npm:wavesurfer.js@6.2.0/dist/wavesurfer.js"
pin "wavesurferregionsjs", to: "https://ga.jspm.io/npm:wavesurfer.js@6.2.0/dist/plugin/wavesurfer.regions.min.js"
pin "@rails/activestorage", to: "https://ga.jspm.io/npm:@rails/activestorage@6.1.4-1/app/assets/javascripts/activestorage.js"
pin "@rails/actioncable", to: "https://ga.jspm.io/npm:@rails/actioncable@6.1.4-1/app/assets/javascripts/action_cable.js"
pin "jitsi" # @2.1.5
pin "popper", to: "https://cdn.skypack.dev/@popperjs/core"
pin "autocomplete", to: "https://ga.jspm.io/npm:@tarekraafat/autocomplete.js@10.2.6/dist/autoComplete.js"
pin "soundtouchjs", to: "https://cdn.jsdelivr.net/npm/soundtouchjs@0.1.30/dist/soundtouch.js"
pin "leaflet", to: "https://ga.jspm.io/npm:leaflet@1.8.0/dist/leaflet-src.js"
pin "lamejs", to: "https://ga.jspm.io/npm:lamejs@1.2.1/src/js/index.js"
