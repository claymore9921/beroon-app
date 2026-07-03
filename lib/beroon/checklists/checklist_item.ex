defmodule Beroon.Checklists.ChecklistItem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "checklist_items" do
    field :title, :string
    field :description, :string
    field :required, :boolean, default: false
    field :position, :integer
    field :active, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(checklist_item, attrs) do
    checklist_item
    |> cast(attrs, [:title, :description, :required, :position, :active])
    |> validate_required([:title, :required, :position, :active])
  end
end
