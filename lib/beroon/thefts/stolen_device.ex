defmodule Beroon.Thefts.StolenDevice do
  use Ecto.Schema
  import Ecto.Changeset

  schema "stolen_devices" do
    field :quantity, :integer, default: 1
    field :plate_snapshot, :string
    field :previous_status, :string
    field :reported_at, :utc_datetime
    field :recovered_at, :utc_datetime
    field :registered_by_phone, :string
    field :notes, :string

    belongs_to :scooter, Beroon.Fleet.Scooter
    belongs_to :branch, Beroon.Operations.Branch
    belongs_to :device_type, Beroon.Fleet.DeviceType

    timestamps(type: :utc_datetime)
  end

  def changeset(stolen_device, attrs) do
    stolen_device
    |> cast(attrs, [
      :scooter_id,
      :branch_id,
      :device_type_id,
      :quantity,
      :plate_snapshot,
      :previous_status,
      :reported_at,
      :recovered_at,
      :registered_by_phone,
      :notes
    ])
    |> validate_required([:branch_id, :device_type_id, :quantity, :reported_at])
    |> validate_number(:quantity, greater_than: 0)
    |> unique_constraint(:scooter_id, name: :one_open_theft_per_scooter)
    |> check_constraint(:quantity, name: :stolen_devices_quantity_must_be_positive)
  end
end
