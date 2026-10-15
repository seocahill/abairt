// Registering the service worker is what makes the browser offer "Add to Home
// Screen", which is the whole point: an icon you tap, not a URL you type.
if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker").catch((error) => {
      console.warn("Service worker registration failed:", error)
    })
  })
}
