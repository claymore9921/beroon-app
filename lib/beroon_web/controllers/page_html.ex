defmodule BeroonWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.
  """
  use BeroonWeb, :html

  embed_templates "page_html/*"

  attr :active, :string, default: "home"

  def manager_bottom_nav(assigns) do
    ~H"""
    <nav class="manager-bottom-nav" aria-label="ناوبری مدیر شعبه">
      <.link navigate={~p"/manager"} class={[@active == "home" && "is-active"]}>
        <.icon class="size-9" name="hero-home" />
        <span>خانه</span>
      </.link>
      <.link navigate={~p"/manager/dinner"} class={[@active == "dinner" && "is-active"]}>
        <.icon class="size-9" name="hero-cake" />
        <span>آمار شام</span>
      </.link>
      <.link navigate={~p"/manager/scan"} class={["is-scan", @active == "scan" && "is-active"]}>
        <span class="manager-scan-bubble">
          <.icon class="size-9" name="hero-qr-code" />
        </span>
        <span>گزارش روزانه</span>
      </.link>
      <.link navigate={~p"/manager/morning"} class={[@active == "checklists" && "is-active"]}>
        <.icon class="size-9" name="hero-clipboard-document-check" />
        <span>چک‌لیست</span>
      </.link>
      <.link navigate={~p"/manager/repairs"} class={[@active == "repairs" && "is-active"]}>
        <.icon class="size-9" name="hero-wrench-screwdriver" />
        <span>خرابی</span>
      </.link>
    </nav>
    """
  end

  attr :active, :string, default: "info"

  def workshop_bottom_nav(assigns) do
    ~H"""
    <nav class="workshop-bottom-nav" aria-label="ناوبری تعمیرگاه">
      <.link navigate={~p"/workshop/info"} class={[@active == "info" && "is-active"]}>
        <.icon class="size-9" name="hero-information-circle" />
        <span>اطلاعات</span>
      </.link>
    </nav>
    """
  end

  attr :title, :string, required: true
  attr :count, :integer, required: true
  attr :items, :list, required: true
  def workshop_status_box(assigns) do
    ~H"""
    <details class="rounded-2xl border border-zinc-200 bg-white p-3 shadow-sm open:col-span-2">
      <summary class="cursor-pointer list-none text-center"><span class="block text-sm font-black text-zinc-700">{@title}</span><strong class="mt-1 block text-3xl font-black text-teal-700">{@count}</strong></summary>
      <div class="mt-3 grid gap-2 border-t border-zinc-100 pt-3">
        <a :for={s <- @items} href={~p"/workshop?q=#{s.plate}"} class="flex items-center justify-between rounded-xl bg-zinc-50 p-3 text-sm"><b>{s.plate}</b><span class="text-zinc-500">{device_type_label(s.device_type)}</span></a>
        <p :if={@items == []} class="text-center text-sm text-zinc-400">موردی وجود ندارد.</p>
      </div>
    </details>
    """
  end

  def workshop_status_label("needs_service"), do: "منتظر پذیرش"
  def workshop_status_label("awaiting_repair"), do: "پذیرش‌شده"
  def workshop_status_label("repairing"), do: "در حال تعمیر"
  def workshop_status_label("waiting_for_part"), do: "در انتظار قطعه"
  def workshop_status_label("ready_for_pickup"), do: "آماده تحویل"
  def workshop_status_label(status), do: status || "-"

  def device_type_label(nil), do: "-"

  def device_type_label(device_type) do
    [
      device_type.device_identifier || device_type.code,
      device_type.category,
      device_type.device_model || device_type.name
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" - ")
  end

  def status_label("active"), do: "فعال"
  def status_label("needs_service"), do: "خراب"
  def status_label("awaiting_repair"), do: "در انتظار تعمیر"
  def status_label("repairing"), do: "در حال تعمیر"
  def status_label("waiting_for_part"), do: "در انتظار قطعه"
  def status_label("ready_for_pickup"), do: "آماده تحویل"
  def status_label("loaned"), do: "امانی"
  def status_label("stolen"), do: "سرقتی"
  def status_label(status), do: status || "-"

  def morning_status_label("ready"), do: "سالم"
  def morning_status_label("needs_service"), do: "نیازمند بررسی"
  def morning_status_label(status), do: status || "-"

  def status_badge_class("active"), do: "bg-emerald-100 text-emerald-700"
  def status_badge_class("needs_service"), do: "bg-red-100 text-red-700"
  def status_badge_class("awaiting_repair"), do: "bg-amber-100 text-amber-700"
  def status_badge_class("repairing"), do: "bg-sky-100 text-sky-700"
  def status_badge_class("waiting_for_part"), do: "bg-purple-100 text-purple-700"
  def status_badge_class("ready_for_pickup"), do: "bg-teal-100 text-teal-700"
  def status_badge_class("loaned"), do: "bg-red-600 text-white"
  def status_badge_class("stolen"), do: "bg-rose-950 text-white"
  def status_badge_class(_status), do: "bg-zinc-100 text-zinc-700"
  def persian_datetime(datetime), do: Beroon.Calendar.persian_datetime(datetime)
  def persian_time(datetime), do: Beroon.Calendar.persian_time(datetime)
  def persian_numeric_date(date), do: Beroon.Calendar.persian_numeric_date(date)

  attr :plate, :string, required: true
  attr :class, :any, default: nil

  def admin_plate_link(assigns) do
    ~H"""
    <.link
      navigate={~p"/admin/devices/#{@plate}"}
      class={["font-black text-orange-700 underline decoration-orange-300 underline-offset-2", @class]}
    >
      {@plate}
    </.link>
    """
  end

  attr :repair_technicians, :list, required: true
  attr :parts, :list, required: true

  def discharge_modal(assigns) do
    ~H"""
    <dialog id="discharge-modal" class="modal modal-bottom sm:modal-middle">
      <div class="modal-box w-[92vw] m-auto max-w-md rounded-2xl bg-white p-5 shadow-2xl">
        <div class="flex items-start justify-between gap-3">
          <div>
            <h2 class="text-lg font-black text-zinc-950">ترخیص دستگاه</h2>
            <p id="discharge-modal-plate" class="mt-1 text-sm text-zinc-500"></p>
          </div>
          <button type="button" id="discharge-modal-close" class="btn btn-ghost btn-sm">بستن</button>
        </div>

        <form id="discharge-modal-form" method="post" action="#">
          <input type="hidden" name="_csrf_token" value={get_csrf_token()} />

          <fieldset class="mt-4 rounded-xl border border-zinc-200 bg-zinc-50 p-3">
            <legend class="px-2 text-sm font-black">تعمیرکار</legend>
            <div class="mt-2 grid gap-2">
              <label :for={name <- @repair_technicians} class="flex cursor-pointer items-center gap-2 rounded-lg border border-zinc-200 bg-white p-3">
                <input type="radio" name="discharge[technician_name]" value={name} required />
                <span class="font-bold">{name}</span>
              </label>
            </div>
          </fieldset>

          <div class="mt-4">
            <div class="flex items-center justify-between">
              <span class="text-sm font-black">قطعات مصرف‌شده</span>
              <button type="button" id="discharge-add-part" class="btn btn-sm btn-neutral gap-1">
                <.icon name="hero-plus" class="size-4" />افزودن قطعه
              </button>
            </div>

            <div id="discharge-part-picker" class="mt-3 hidden rounded-xl border border-teal-200 bg-teal-50 p-3">
              <select id="discharge-part-select" class="select select-bordered w-full">
                <option value="">-- انتخاب قطعه --</option>
                <option :for={part <- @parts} value={part.id} data-name={part.name}>
                  {part.name} (موجودی: {part.quantity})
                </option>
              </select>
              <div class="mt-2 flex gap-2">
                <input id="discharge-part-qty" type="number" min="1" value="1" class="input input-bordered w-24" placeholder="تعداد" />
                <button type="button" id="discharge-part-confirm" class="btn btn-primary flex-1">افزودن به لیست</button>
              </div>
            </div>

            <div id="discharge-parts-rows" class="mt-3 grid gap-2"></div>
            <p id="discharge-parts-empty" class="mt-2 text-sm text-zinc-500">هنوز قطعه‌ای اضافه نشده است.</p>
          </div>

          <button type="submit" class="btn btn-primary mt-5 min-h-12 w-full">ترخیص دستگاه</button>
        </form>
      </div>
      <form method="dialog" class="modal-backdrop"><button aria-label="بستن"></button></form>
    </dialog>
    """
  end
end
