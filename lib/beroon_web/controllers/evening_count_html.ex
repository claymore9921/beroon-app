defmodule BeroonWeb.EveningCountHTML do
  use BeroonWeb, :html

  embed_templates "evening_count_html/*"

  @doc """
  Renders a evening_count form.

  The form is defined in the template at
  evening_count_html/evening_count_form.html.heex
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true
  attr :return_to, :string, default: nil

  def evening_count_form(assigns)
end
