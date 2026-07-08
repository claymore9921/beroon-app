defmodule BeroonWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.
  """
  use BeroonWeb, :html

  embed_templates "page_html/*"

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
  def status_label("out_of_service"), do: "از مدار خارج شده"
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
  def status_badge_class("out_of_service"), do: "bg-zinc-200 text-zinc-700"
  def status_badge_class(_status), do: "bg-zinc-100 text-zinc-700"
end
