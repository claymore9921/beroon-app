defmodule BeroonWeb.DeviceTypeHTML do
  use BeroonWeb, :html

  embed_templates "device_type_html/*"

  attr :form, Phoenix.HTML.Form, required: true
  attr :action, :string, required: true
  attr :return_to, :string, default: nil

  def device_type_form(assigns)
end
