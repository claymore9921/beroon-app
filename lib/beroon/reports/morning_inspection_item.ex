defmodule Beroon.Reports.MorningInspectionItem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "morning_inspection_items" do
    field :checked, :boolean, default: false
    field :morning_inspection_id, :id
    field :checklist_item_id, :id

    timestamps(type: :utc_datetime)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:morning_inspection_id, :checklist_item_id, :checked])
    |> validate_required([:morning_inspection_id, :checklist_item_id, :checked])
    |> unique_constraint([:morning_inspection_id, :checklist_item_id])
  end
end
