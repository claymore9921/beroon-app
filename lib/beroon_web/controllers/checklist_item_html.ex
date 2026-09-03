defmodule BeroonWeb.ChecklistItemHTML do
  use BeroonWeb, :html

  embed_templates "checklist_item_html/*"

  @doc """
  Renders a checklist_item form.

  The form is defined in the template at
  checklist_item_html/checklist_item_form.html.heex
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true
  attr :return_to, :string, default: nil

  def checklist_item_form(assigns)
end
