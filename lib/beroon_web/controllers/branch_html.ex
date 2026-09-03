defmodule BeroonWeb.BranchHTML do
  use BeroonWeb, :html

  embed_templates "branch_html/*"

  @doc """
  Renders a branch form.

  The form is defined in the template at
  branch_html/branch_form.html.heex
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true
  attr :return_to, :string, default: nil

  def branch_form(assigns)
end
