defmodule Beroon.Reports.WorkshopEvent do
  use Ecto.Schema
  import Ecto.Changeset

  schema "workshop_events" do
    field :event_type, :string
    field :event_on, :date
    field :event_at, :utc_datetime
    field :registered_by_phone, :string
    field :technician_name, :string
    field :repair_parts_used, :string
    field :discharge_notes, :string
    belongs_to :scooter, Beroon.Fleet.Scooter
    timestamps(type: :utc_datetime)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:scooter_id, :event_type, :event_on, :event_at, :registered_by_phone, :technician_name, :repair_parts_used, :discharge_notes])
    |> validate_required([:scooter_id, :event_type, :event_on, :event_at])
    |> validate_inclusion(:event_type, ["accepted", "repair_started", "discharged"])
  end
end
