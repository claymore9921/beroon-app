// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/beroon"
import jsQR from "../vendor/jsQR"
import topbar from "../vendor/topbar"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

const buildScannedCard = (scooter) => {
  const deviceTypeLabel = [
    scooter.device_type_identifier,
    scooter.device_type_category,
    scooter.device_type_name,
  ].filter(Boolean).join(" - ") || "نوع ثبت نشده"

  const hidden = document.createElement("input")
  hidden.type = "hidden"
  hidden.name = "evening[scanned_codes][]"
  hidden.value = scooter.plate

  const card = document.createElement("div")
  card.className = "rounded-md bg-white p-3 text-sm"
  card.innerHTML = `
    <div class="flex items-start justify-between gap-2">
      <div>
        <p class="font-bold">${scooter.plate || "-"}</p>
        <p class="text-zinc-500">${deviceTypeLabel}</p>
        <p class="text-zinc-500">${scooter.branch_name || "شعبه نامشخص"}</p>
      </div>
    </div>
  `
  card.appendChild(hidden)
  return card
}

const lookupScooter = async (code) => {
  const clean = (code || "").trim()
  if (!clean) return null

  const response = await fetch(`/api/scooters/lookup?code=${encodeURIComponent(clean)}`)
  if (!response.ok) {
    alert("این پلاک قبلا توسط ادمین ثبت نشده است.")
    return null
  }

  const payload = await response.json()
  return payload.scooter
}

const addScannedScooter = (scooter) => {
  const list = document.getElementById("scanned-list")
  const count = document.getElementById("scan-count")
  if (!list || !count) return

  if (list.querySelector(`input[value="${CSS.escape(scooter.plate)}"]`)) return

  list.prepend(buildScannedCard(scooter))
  count.textContent = String(list.querySelectorAll('input[name="evening[scanned_codes][]"]').length)
}

const setupEveningScanner = () => {
  const startPanel = document.getElementById("start-panel")
  const startButton = document.getElementById("start-count")
  const scanButton = document.getElementById("scan-button")
  const input = document.getElementById("scan-input")
  const manualAdd = document.getElementById("manual-add")
  const dialog = document.getElementById("scan-dialog")
  const closeButton = document.getElementById("scan-close")
  const retryButton = document.getElementById("scan-retry")
  const status = document.getElementById("scan-status")
  const video = document.getElementById("scan-video")

  if (!startButton || !startPanel || !scanButton || !input || !manualAdd || !dialog || !video || !status) return

  let stream = null
  let scanning = false
  const seenPlates = new Set()

  startButton.addEventListener("click", () => {
    startPanel.classList.add("hidden")
    const form = document.getElementById("count-form")
    form?.classList.remove("hidden")
  })

  const stopScanner = () => {
    scanning = false

    if (stream) {
      stream.getTracks().forEach((track) => track.stop())
      stream = null
    }

    video.pause()
    video.srcObject = null

    if (dialog.open) dialog.close()
  }

  const scanFrame = async () => {
    if (!scanning || !stream) return

    const canvas = document.createElement("canvas")
    const context = canvas.getContext("2d", {willReadFrequently: true})
    if (!context) {
      status.textContent = "اسکنر آماده نشد. دوباره تلاش کنید."
      stopScanner()
      return
    }

    canvas.width = video.videoWidth
    canvas.height = video.videoHeight
    context.drawImage(video, 0, 0, canvas.width, canvas.height)

    const imageData = context.getImageData(0, 0, canvas.width, canvas.height)
    const code = jsQR(imageData.data, imageData.width, imageData.height, {inversionAttempts: "attemptBoth"})

    if (code?.data) {
      const scooter = await lookupScooter(code.data)
      if (scooter) {
        if (!seenPlates.has(scooter.plate)) {
          seenPlates.add(scooter.plate)
          addScannedScooter(scooter)
        }
        input.value = scooter.plate || code.data
      }
      stopScanner()
      return
    }

    requestAnimationFrame(scanFrame)
  }

  const openScanner = async () => {
    if (!navigator.mediaDevices?.getUserMedia) {
      alert("این دستگاه دسترسی به دوربین را پشتیبانی نمی‌کند.")
      return
    }

    dialog.showModal()
    status.textContent = "در حال اتصال به دوربین..."
    scanning = true

    try {
      stream = await navigator.mediaDevices.getUserMedia({video: {facingMode: "environment"}})
      video.srcObject = stream
      await video.play()
      status.textContent = "دوربین فعال است. QR را مقابل دوربین بگیرید."
      scanFrame()
    } catch (_error) {
      status.textContent = "دسترسی به دوربین ممکن نشد."
      stopScanner()
    }
  }

  scanButton.addEventListener("click", openScanner)
  manualAdd.addEventListener("click", async () => {
    const scooter = await lookupScooter(input.value)
    if (!scooter) return
    addScannedScooter(scooter)
    input.value = ""
  })
  closeButton.addEventListener("click", stopScanner)
  retryButton?.addEventListener("click", async () => {
    stopScanner()
    await openScanner()
  })
  dialog.addEventListener("cancel", (event) => {
    event.preventDefault()
    stopScanner()
  })
}

const setupMorningChecklist = () => {
  const checkAll = document.getElementById("check-all-morning-items")
  if (checkAll) {
    checkAll.addEventListener("click", () => {
      document.querySelectorAll(".morning-check-item").forEach(item => item.checked = true)
    })
  }

  const scanButton = document.getElementById("morning-scan-button")
  const input = document.getElementById("morning-code-input")
  const form = document.getElementById("morning-scan-form")
  const dialog = document.getElementById("morning-scan-dialog")
  const closeButton = document.getElementById("morning-scan-close")
  const retryButton = document.getElementById("morning-scan-retry")
  const status = document.getElementById("morning-scan-status")
  const video = document.getElementById("morning-scan-video")

  if (!scanButton || !input || !video || !form || !dialog || !status) return

  let stream = null
  let scanning = false

  const stopScanner = () => {
    scanning = false

    if (stream) {
      stream.getTracks().forEach((track) => track.stop())
      stream = null
    }

    video.pause()
    video.srcObject = null

    if (dialog.open) dialog.close()
  }

  const scanFrame = async () => {
    if (!scanning || !stream) return

    const canvas = document.createElement("canvas")
    const context = canvas.getContext("2d", {willReadFrequently: true})
    if (!context) {
      status.textContent = "اسکنر آماده نشد. دوباره تلاش کنید."
      stopScanner()
      return
    }

    canvas.width = video.videoWidth
    canvas.height = video.videoHeight
    context.drawImage(video, 0, 0, canvas.width, canvas.height)

    const imageData = context.getImageData(0, 0, canvas.width, canvas.height)
    const code = jsQR(imageData.data, imageData.width, imageData.height, {inversionAttempts: "attemptBoth"})

    if (code?.data) {
      const scooter = await lookupScooter(code.data)
      if (scooter) {
        input.value = scooter.barcode || scooter.plate || code.data
        stopScanner()
        form.requestSubmit()
        return
      }

      stopScanner()
      return
    }

    requestAnimationFrame(scanFrame)
  }

  const openScanner = async () => {
    if (!navigator.mediaDevices?.getUserMedia) {
      alert("این دستگاه دسترسی به دوربین را پشتیبانی نمی‌کند.")
      return
    }

    dialog.showModal()
    status.textContent = "در حال اتصال به دوربین..."
    scanning = true

    try {
      stream = await navigator.mediaDevices.getUserMedia({video: {facingMode: "environment"}})
      video.srcObject = stream
      await video.play()
      status.textContent = "دوربین فعال است. QR را مقابل دوربین بگیرید."
      scanFrame()
    } catch (_error) {
      status.textContent = "دسترسی به دوربین ممکن نشد."
      stopScanner()
    }
  }

  scanButton.addEventListener("click", openScanner)
  closeButton.addEventListener("click", stopScanner)
  retryButton?.addEventListener("click", async () => {
    stopScanner()
    await openScanner()
  })
  dialog.addEventListener("cancel", (event) => {
    event.preventDefault()
    stopScanner()
  })
}

const setupScooterFormScanner = () => {
  const scanButton = document.getElementById("scooter-scan-button")
  const plateInput = document.getElementById("scooter-plate-input")
  const barcodeInput = document.getElementById("scooter-barcode-input")
  const dialog = document.getElementById("scooter-scan-dialog")
  const closeButton = document.getElementById("scooter-scan-close")
  const retryButton = document.getElementById("scooter-scan-retry")
  const status = document.getElementById("scooter-scan-status")
  const video = document.getElementById("scooter-scan-video")

  if (!scanButton || !plateInput || !barcodeInput || !dialog || !closeButton || !retryButton || !status || !video) return

  let stream = null
  let scanning = false

  const stopScanner = () => {
    scanning = false

    if (stream) {
      stream.getTracks().forEach((track) => track.stop())
      stream = null
    }

    video.pause()
    video.srcObject = null

    if (dialog.open) dialog.close()
  }

  const scanFrame = async () => {
    if (!scanning || !stream) return

    const canvas = document.createElement("canvas")
    const context = canvas.getContext("2d", {willReadFrequently: true})
    if (!context) {
      status.textContent = "اسکنر آماده نشد. دوباره تلاش کنید."
      stopScanner()
      return
    }

    canvas.width = video.videoWidth
    canvas.height = video.videoHeight
    context.drawImage(video, 0, 0, canvas.width, canvas.height)

    const imageData = context.getImageData(0, 0, canvas.width, canvas.height)
    const code = jsQR(imageData.data, imageData.width, imageData.height, {inversionAttempts: "attemptBoth"})

    if (code?.data) {
      const scannedValue = code.data.trim()
      plateInput.value = scannedValue
      barcodeInput.value = scannedValue
      plateInput.focus()
      stopScanner()
      return
    }

    requestAnimationFrame(scanFrame)
  }

  const openScanner = async () => {
    if (!navigator.mediaDevices?.getUserMedia) {
      alert("این دستگاه دسترسی به دوربین را پشتیبانی نمی‌کند.")
      return
    }

    dialog.showModal()
    status.textContent = "در حال اتصال به دوربین..."
    scanning = true

    try {
      stream = await navigator.mediaDevices.getUserMedia({video: {facingMode: "environment"}})
      video.srcObject = stream
      await video.play()
      status.textContent = "دوربین فعال است. QR را مقابل دوربین بگیرید."
      scanFrame()
    } catch (_error) {
      status.textContent = "دسترسی به دوربین ممکن نشد."
      stopScanner()
    }
  }

  scanButton.addEventListener("click", openScanner)
  closeButton.addEventListener("click", stopScanner)
  retryButton.addEventListener("click", async () => {
    stopScanner()
    await openScanner()
  })
  dialog.addEventListener("cancel", (event) => {
    event.preventDefault()
    stopScanner()
  })
}

window.addEventListener("DOMContentLoaded", setupMorningChecklist)
window.addEventListener("DOMContentLoaded", setupEveningScanner)
window.addEventListener("DOMContentLoaded", setupScooterFormScanner)

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}
