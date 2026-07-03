defmodule BeroonWeb.MorningInspectionHTML do
  use BeroonWeb, :html

  embed_templates "morning_inspection_html/*"

  @doc """
  Renders a morning_inspection form.

  The form is defined in the template at
  morning_inspection_html/morning_inspection_form.html.heex
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true
  attr :return_to, :string, default: nil

  def morning_inspection_form(assigns)
end
