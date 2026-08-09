defmodule Beroon.LocationHistory.LocationEvent do
  use Ecto.Schema
  import Ecto.Changeset

  schema "scooter_location_events" do
    field :observed_at, :utc_datetime
    belongs_to :scooter, Beroon.Fleet.Scooter
    belongs_to :branch, Beroon.Operations.Branch

    timestamps(type: :utc_datetime)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:scooter_id, :branch_id, :observed_at])
    |> validate_required([:scooter_id, :branch_id, :observed_at])
  end
end
