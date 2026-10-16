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

// Chrome will not offer "Install app" without a fetch handler that can answer
// a navigation while offline — a worker handling only install and activate is
// not installable at all, whatever the manifest says. Safari does not care,
// which is why this was easy to miss.
//
// Navigations only, and only when the network has actually failed: everything
// else goes straight past. Nothing is ever cached, so there is no way to serve
// a stale page or a stale recording — offline looks like this notice, and the
// moment there is signal again a reload gets the real thing.
const OFFLINE_PAGE = `<!DOCTYPE html>
<html lang="ga">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Abairt</title>
    <style>
      body {
        margin: 0;
        min-height: 100vh;
        display: grid;
        place-items: center;
        padding: 2rem;
        background: #1e3a2f;
        color: #f8fafc;
        font-family: system-ui, -apple-system, sans-serif;
        text-align: center;
        line-height: 1.5;
      }
      p { margin: 0 0 0.5rem; font-size: 1.125rem; }
      small { opacity: 0.7; }
    </style>
  </head>
  <body>
    <div>
      <p>Níl aon cheangal ann faoi láthair.</p>
      <small>Bain triail eile as nuair a bheidh comhartha agat.</small>
    </div>
  </body>
</html>`

self.addEventListener("fetch", (event) => {
  if (event.request.mode !== "navigate") return

  event.respondWith(
    fetch(event.request).catch(
      () =>
        new Response(OFFLINE_PAGE, {
          status: 200,
          headers: { "Content-Type": "text/html; charset=utf-8" }
        })
    )
  )
})
