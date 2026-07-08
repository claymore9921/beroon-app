defmodule BeroonWeb.ScooterHTML do
  use BeroonWeb, :html

  embed_templates "scooter_html/*"

  @doc """
  Renders a scooter form.

  The form is defined in the template at
  scooter_html/scooter_form.html.heex
  """
  attr :form, Phoenix.HTML.Form, required: true
  attr :branches, :list, required: true
  attr :device_types, :list, required: true
  attr :action, :string, required: true
  attr :return_to, :string, default: nil

  def scooter_form(assigns)

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

  def status_options do
    [
      {"فعال", "active"},
      {"خراب", "needs_service"},
      {"در انتظار تعمیر", "awaiting_repair"},
      {"در حال تعمیر", "repairing"},
      {"در انتظار قطعه", "waiting_for_part"},
      {"آماده تحویل", "ready_for_pickup"},
      {"از مدار خارج شده", "out_of_service"}
    ]
  end
end
