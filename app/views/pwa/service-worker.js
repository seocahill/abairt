// Deliberately minimal: enough to make the app installable, and no caching of
// anything that matters.
//
// A learner records a question and it is uploaded immediately — stale cached
// HTML or a half-cached recording would be worse than being plainly offline, so
// requests always go to the network and failures stay visible.

self.addEventListener("install", () => self.skipWaiting())

self.addEventListener("activate", (event) => {
  event.waitUntil(self.clients.claim())
})
