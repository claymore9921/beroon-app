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
  card.dataset.plate = scooter.plate || ""
  card.innerHTML = `
    <div class="flex items-start justify-between gap-2">
      <div>
        <p class="font-bold">${scooter.plate || "-"}</p>
        <p class="text-zinc-500">${deviceTypeLabel}</p>
        <p class="text-zinc-500">${scooter.branch_name || "شعبه نامشخص"}</p>
      </div>
      <button
        type="button"
        class="evening-remove-scan inline-flex h-7 min-h-0 items-center justify-center rounded-md border border-red-200 bg-red-50 px-2 text-xs font-bold text-red-700 hover:bg-red-100"
        aria-label="حذف پلاک ${scooter.plate || ""}"
      >
        حذف
      </button>
    </div>
  `
  card.appendChild(hidden)
  return card
}


const attachTorchControl = (dialog, stream) => {
  if (!dialog || !stream) return

  let button = dialog.querySelector("[data-qr-torch-button]")
  if (!button) {
    button = document.createElement("button")
    button.type = "button"
    button.dataset.qrTorchButton = "true"
    button.className = "btn btn-sm mt-3 w-full"
    button.textContent = "روشن کردن فلش"
    const video = dialog.querySelector("video")
    video?.insertAdjacentElement("afterend", button)
  }

  const track = stream.getVideoTracks()[0]
  const capabilities = track?.getCapabilities?.() || {}
  let enabled = false

  button.disabled = !capabilities.torch
  button.textContent = capabilities.torch ? "روشن کردن فلش" : "فلش در این گوشی پشتیبانی نمی‌شود"
  button.onclick = async () => {
    if (!capabilities.torch) return
    enabled = !enabled
    try {
      await track.applyConstraints({advanced: [{torch: enabled}]})
      button.textContent = enabled ? "خاموش کردن فلش" : "روشن کردن فلش"
    } catch (error) {
      console.error("Camera torch error:", error)
      enabled = false
      button.textContent = "روشن کردن فلش"
      alert("فعال‌کردن فلش دوربین در این مرورگر ممکن نشد.")
    }
  }
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

const registerEveningScan = async (code) => {
  const clean = String(code || "").trim()
  if (!clean) return null

  const body = new URLSearchParams({code: clean})
  const response = await fetch("/api/scooters/evening-scan", {
    method: "POST",
    headers: {
      "content-type": "application/x-www-form-urlencoded;charset=UTF-8",
      "x-csrf-token": csrfToken,
    },
    body: body.toString(),
  })

  let payload = {}
  try { payload = await response.json() } catch (_error) { payload = {} }

  if (response.ok) return payload.scooter

  if (payload.error === "transport_foreign") {
    alert("این دستگاه برای حمل‌ونقل انتخاب شده و نباید جزو آمار این شعبه ثبت شود.")
  } else if (payload.error === "loaned") {
    alert("این دستگاه امانی است و در آمار شب ثبت نمی‌شود.")
  } else if (payload.error === "stolen") {
    alert("این دستگاه سرقتی است و در آمار شب ثبت نمی‌شود.")
  } else if (payload.error === "not_found") {
    alert("این پلاک قبلا توسط ادمین ثبت نشده است.")
  } else {
    alert("ثبت محل دستگاه انجام نشد. دوباره تلاش کنید.")
  }

  return null
}

const addScannedScooter = (scooter) => {
  const list = document.getElementById("scanned-list")
  const count = document.getElementById("scan-count")
  if (!list || !count) return

  if (list.querySelector(`input[value="${CSS.escape(scooter.plate)}"]`)) return

  list.prepend(buildScannedCard(scooter))
  count.textContent = String(list.querySelectorAll('input[name="evening[scanned_codes][]"]').length)
  document.dispatchEvent(new CustomEvent("evening:scan-added", {detail: scooter}))
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
  if (scanButton.dataset.scannerBound === "true") return
  scanButton.dataset.scannerBound = "true"

  let stream = null
  let scanning = false
  const seenPlates = new Set()
  const form = document.getElementById("count-form")
  const managerBranchId = Number(form?.dataset.branchId || 0)
  const reportDate = form?.dataset.reportDate || "current"
  const storageKey = `beroon-evening-draft-${managerBranchId}-${reportDate}`

  const saveDraft = () => {
    const codes = Array.from(document.querySelectorAll('input[name="evening[scanned_codes][]"]')).map(el => el.value)
    localStorage.setItem(storageKey, JSON.stringify(codes))
  }

  const restoreDraft = async () => {
    let codes = []
    try { codes = JSON.parse(localStorage.getItem(storageKey) || "[]") } catch (_e) { codes = [] }
    for (const code of codes) {
      const scooter = await lookupScooter(code)
      if (scooter && !seenPlates.has(scooter.plate)) {
        seenPlates.add(scooter.plate)
        addScannedScooter(scooter)
      }
    }
    if (codes.length > 0) {
      startPanel.classList.add("hidden")
      form?.classList.remove("hidden")
    }
  }

  document.addEventListener("evening:scan-added", saveDraft)

  const scannedList = document.getElementById("scanned-list")
  scannedList?.addEventListener("click", (event) => {
    const button = event.target.closest(".evening-remove-scan")
    if (!button) return

    const card = button.closest("[data-plate]")
    const plate = card?.dataset.plate || ""
    if (!card || !plate) return

    if (!window.confirm(`پلاک ${plate} از آمار در حال ثبت حذف شود؟`)) return

    seenPlates.delete(plate)
    card.remove()

    const count = document.getElementById("scan-count")
    if (count) {
      count.textContent = String(document.querySelectorAll('input[name="evening[scanned_codes][]"]').length)
    }

    saveDraft()
    input.value = ""
    requestAnimationFrame(() => input.focus({preventScroll: true}))
  })

  restoreDraft()

  startButton.addEventListener("click", () => {
    startPanel.classList.add("hidden")
    const form = document.getElementById("count-form")
    form?.classList.remove("hidden")
    requestAnimationFrame(() => input.focus({preventScroll: true}))
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
      const original = await lookupScooter(code.data)
      if (original) {
        const scooter = await registerEveningScan(original.plate || code.data)
        if (scooter) {
          if (scooter.branch_id !== managerBranchId) {
            alert(`این دستگاه متعلق به ${scooter.branch_name || "شعبه دیگری"} است؛ محل فعلی آن به این شعبه تغییر کرد و در آمار این شعبه ثبت می‌شود.`)
          }
          if (!seenPlates.has(scooter.plate)) {
            seenPlates.add(scooter.plate)
            addScannedScooter(scooter)
          }
          input.value = scooter.plate || code.data
        } else {
          input.value = ""
        }
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
      attachTorchControl(dialog, stream)
      status.textContent = "دوربین فعال است. QR را مقابل دوربین بگیرید."
      scanFrame()
    } catch (_error) {
      status.textContent = "دسترسی به دوربین ممکن نشد."
      stopScanner()
    }
  }

  scanButton.addEventListener("click", openScanner)
  manualAdd.addEventListener("click", async () => {
    const clean = String(input.value || "").trim()
    if (!/^\d{4}$/.test(clean)) {
      alert("پلاک را به‌صورت عدد ۴ رقمی وارد کنید.")
      input.focus({preventScroll: true})
      return
    }

    const original = await lookupScooter(clean)
    if (!original) {
      input.focus({preventScroll: true})
      return
    }

    const scooter = await registerEveningScan(original.plate || clean)
    if (scooter) {
      if (scooter.branch_id !== managerBranchId) {
        alert(`این دستگاه متعلق به ${scooter.branch_name || "شعبه دیگری"} است؛ محل فعلی آن به این شعبه تغییر کرد و در آمار این شعبه ثبت می‌شود.`)
      }
      if (!seenPlates.has(scooter.plate)) {
        seenPlates.add(scooter.plate)
        addScannedScooter(scooter)
      }
    }

    input.value = ""
    requestAnimationFrame(() => input.focus({preventScroll: true}))
  })

  input.addEventListener("keydown", (event) => {
    if (event.key === "Enter") {
      event.preventDefault()
      manualAdd.click()
    }
  })

  form?.addEventListener("submit", (event) => {
    if (!window.confirm("آیا از پایان آمارگیری و ثبت نهایی آن مطمئن هستید؟ پس از ثبت نهایی، برای اصلاح باید با ادمین هماهنگ کنید.")) {
      event.preventDefault()
      return
    }

    // پس از تأیید نهایی، پیش‌نویس محلی پاک می‌شود تا اگر ادمین همان شب
    // آمار را مجدداً باز کرد، فرم با اسکن‌های قبلی پر نشود.
    localStorage.removeItem(storageKey)
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
      document.querySelectorAll('input[type="checkbox"][name="morning[checked_item_ids][]"]').forEach(item => { item.checked = true; item.dispatchEvent(new Event("change", {bubbles: true})) })
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
  if (scanButton.dataset.scannerBound === "true") return
  scanButton.dataset.scannerBound = "true"

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
        const managerBranchId = Number(form.dataset.branchId || 0)
        if (scooter.status === "transport" && scooter.branch_id !== managerBranchId) {
          alert("این دستگاه برای حمل‌ونقل انتخاب شده و در چک‌لیست این شعبه ثبت نمی‌شود.")
          input.value = ""
          stopScanner()
          return
        }
        if (scooter.branch_id !== managerBranchId) {
          alert(`این دستگاه متعلق به ${scooter.branch_name || "شعبه دیگری"} است و در چک‌لیست این شعبه ثبت نمی‌شود.`)
          input.value = ""
          stopScanner()
          return
        }
        input.value = scooter.barcode || scooter.plate || code.data
        input.blur()
        if (document.activeElement instanceof HTMLElement) document.activeElement.blur()
        stopScanner()
        window.scrollTo({top: 0, behavior: "auto"})
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
      attachTorchControl(dialog, stream)
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
  if (scanButton.dataset.scannerBound === "true") return
  scanButton.dataset.scannerBound = "true"

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
      attachTorchControl(dialog, stream)
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


const setupSearchScanner = ({
  buttonId,
  inputId,
  formId,
  dialogId,
  videoId,
  statusId,
  closeId,
  retryId,
  autoSubmit = true,
}) => {
  const scanButton = document.getElementById(buttonId)
  const input = document.getElementById(inputId)
  const form = document.getElementById(formId)
  const dialog = document.getElementById(dialogId)
  const video = document.getElementById(videoId)
  const status = document.getElementById(statusId)
  const closeButton = document.getElementById(closeId)
  const retryButton = document.getElementById(retryId)

  if (!scanButton || !input || !form || !dialog || !video || !status || !closeButton) return
  if (scanButton.dataset.scannerBound === "true") return
  scanButton.dataset.scannerBound = "true"

  let stream = null
  let scanning = false
  let animationFrameId = null

  const stopCamera = () => {
    scanning = false

    if (animationFrameId !== null) {
      cancelAnimationFrame(animationFrameId)
      animationFrameId = null
    }

    if (stream) {
      stream.getTracks().forEach(track => track.stop())
      stream = null
    }

    video.pause()
    video.srcObject = null
  }

  const stopScanner = () => {
    stopCamera()
    if (dialog.open) dialog.close()
  }

  const scanFrame = () => {
    if (!scanning || !stream) return

    if (video.readyState < video.HAVE_ENOUGH_DATA) {
      animationFrameId = requestAnimationFrame(scanFrame)
      return
    }

    const canvas = document.createElement("canvas")
    const context = canvas.getContext("2d", {willReadFrequently: true})

    if (!context) {
      status.textContent = "اسکنر آماده نشد. دوباره تلاش کنید."
      stopCamera()
      return
    }

    canvas.width = video.videoWidth
    canvas.height = video.videoHeight
    context.drawImage(video, 0, 0, canvas.width, canvas.height)

    const imageData = context.getImageData(0, 0, canvas.width, canvas.height)
    const code = jsQR(imageData.data, imageData.width, imageData.height, {
      inversionAttempts: "attemptBoth",
    })

    if (code?.data) {
      const value = code.data.trim()

      if (value) {
        input.value = value
        input.dispatchEvent(new Event("input", {bubbles: true}))
        input.dispatchEvent(new Event("change", {bubbles: true}))
        stopScanner()
        input.focus()

        if (autoSubmit) form.requestSubmit()
        return
      }
    }

    animationFrameId = requestAnimationFrame(scanFrame)
  }

  const openScanner = async () => {
    if (!navigator.mediaDevices?.getUserMedia) {
      alert("این دستگاه دسترسی به دوربین را پشتیبانی نمی‌کند.")
      return
    }

    stopCamera()
    if (!dialog.open) dialog.showModal()
    status.textContent = "در حال اتصال به دوربین..."
    scanning = true

    try {
      stream = await navigator.mediaDevices.getUserMedia({
        video: {facingMode: {ideal: "environment"}},
        audio: false,
      })
      video.srcObject = stream
      await video.play()
      attachTorchControl(dialog, stream)
      status.textContent = "دوربین فعال است. QR را مقابل دوربین بگیرید."
      animationFrameId = requestAnimationFrame(scanFrame)
    } catch (error) {
      console.error("QR scanner camera error:", error)
      stopCamera()
      status.textContent = "دسترسی به دوربین ممکن نشد. مجوز دوربین را بررسی کنید."
    }
  }

  scanButton.addEventListener("click", openScanner)
  closeButton.addEventListener("click", stopScanner)
  retryButton?.addEventListener("click", openScanner)
  dialog.addEventListener("cancel", event => {
    event.preventDefault()
    stopScanner()
  })
  dialog.addEventListener("close", stopCamera)
}

const bootScannerPages = () => {
  setupMorningChecklist()
  setupEveningScanner()
  setupScooterFormScanner()

  setupSearchScanner({
    buttonId: "manager-repair-scan",
    inputId: "repair-plate-search",
    formId: "manager-repair-search",
    dialogId: "manager-repair-scan-dialog",
    videoId: "manager-repair-scan-video",
    statusId: "manager-repair-scan-status",
    closeId: "manager-repair-scan-close",
    retryId: "manager-repair-scan-retry",
  })

  setupSearchScanner({
    buttonId: "workshop-home-scan",
    inputId: "workshop-home-q",
    formId: "workshop-home-search",
    dialogId: "workshop-home-scan-dialog",
    videoId: "workshop-home-scan-video",
    statusId: "workshop-home-scan-status",
    closeId: "workshop-home-scan-close",
    retryId: "workshop-home-scan-retry",
  })

  setupSearchScanner({
    buttonId: "workshop-acceptance-scan",
    inputId: "workshop-acceptance-q",
    formId: "workshop-acceptance-search",
    dialogId: "workshop-acceptance-scan-dialog",
    videoId: "workshop-acceptance-scan-video",
    statusId: "workshop-acceptance-scan-status",
    closeId: "workshop-acceptance-scan-close",
    retryId: "workshop-acceptance-scan-retry",
  })

  setupSearchScanner({
    buttonId: "workshop-repairing-scan",
    inputId: "workshop-repairing-q",
    formId: "workshop-repairing-search",
    dialogId: "workshop-repairing-scan-dialog",
    videoId: "workshop-repairing-scan-video",
    statusId: "workshop-repairing-scan-status",
    closeId: "workshop-repairing-scan-close",
    retryId: "workshop-repairing-scan-retry",
  })

  setupSearchScanner({
    buttonId: "workshop-discharge-scan",
    inputId: "workshop-discharge-q",
    formId: "workshop-discharge-search",
    dialogId: "workshop-discharge-scan-dialog",
    videoId: "workshop-discharge-scan-video",
    statusId: "workshop-discharge-scan-status",
    closeId: "workshop-discharge-scan-close",
    retryId: "workshop-discharge-scan-retry",
  })

  setupSearchScanner({
    buttonId: "manager-repair-receive-scan",
    inputId: "receive-repaired-scooter-plate",
    formId: "receive-repaired-scooter-form",
    dialogId: "manager-repair-receive-scan-dialog",
    videoId: "manager-repair-receive-scan-video",
    statusId: "manager-repair-receive-scan-status",
    closeId: "manager-repair-receive-scan-close",
    retryId: "manager-repair-receive-scan-retry",
    autoSubmit: false,
  })


  setupSearchScanner({
    buttonId: "manager-transport-scan",
    inputId: "manager-transport-code",
    formId: "manager-transport-form",
    dialogId: "manager-transport-scan-dialog",
    videoId: "manager-transport-scan-video",
    statusId: "manager-transport-scan-status",
    closeId: "manager-transport-scan-close",
    retryId: "manager-transport-scan-retry",
    autoSubmit: false,
  })

  setupSearchScanner({
    buttonId: "admin-scooter-search-scan",
    inputId: "scooter-search",
    formId: "scooter-search-form",
    dialogId: "admin-scooter-search-scan-dialog",
    videoId: "admin-scooter-search-scan-video",
    statusId: "admin-scooter-search-scan-status",
    closeId: "admin-scooter-search-scan-close",
    retryId: "admin-scooter-search-scan-retry",
  })

  setupSearchScanner({
    buttonId: "admin-device-location-scan",
    inputId: "admin-device-location-q",
    formId: "admin-device-location-search",
    dialogId: "admin-device-location-scan-dialog",
    videoId: "admin-device-location-scan-video",
    statusId: "admin-device-location-scan-status",
    closeId: "admin-device-location-scan-close",
    retryId: "admin-device-location-scan-retry",
  })
}

const setupAdminMenu = () => {
  const menu = document.querySelector(".beroon-mobile-menu")
  if (!menu || menu.dataset.menuReady === "true") return

  menu.dataset.menuReady = "true"

  const closeMenu = () => menu.removeAttribute("open")

  menu.querySelectorAll("[data-admin-menu-close]").forEach((button) => {
    button.addEventListener("click", closeMenu)
  })

  menu.querySelectorAll(".beroon-menu-panel a").forEach((link) => {
    link.addEventListener("click", closeMenu)
  })

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && menu.open) closeMenu()
  })
}

window.addEventListener("DOMContentLoaded", bootScannerPages)
window.addEventListener("DOMContentLoaded", setupAdminMenu)
window.addEventListener("phx:page-loading-stop", bootScannerPages)
window.addEventListener("phx:page-loading-stop", setupAdminMenu)

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
