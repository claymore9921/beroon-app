defmodule Beroon.Parts.RepairPartUsage do
  use Ecto.Schema
  import Ecto.Changeset

  schema "repair_part_usages" do
    field :part_name, :string
    field :quantity, :integer, default: 1
    belongs_to :part, Beroon.Parts.Part
    belongs_to :workshop_event, Beroon.Reports.WorkshopEvent

    timestamps(type: :utc_datetime)
  end

  def changeset(usage, attrs) do
    usage
    |> cast(attrs, [:workshop_event_id, :part_id, :part_name, :quantity])
    |> validate_required([:workshop_event_id, :part_name, :quantity])
    |> validate_number(:quantity, greater_than: 0)
  end
end
