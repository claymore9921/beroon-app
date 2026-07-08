defmodule Beroon.Reports.ScooterRepairReport do
  use Ecto.Schema
  import Ecto.Changeset

  schema "scooter_repair_reports" do
    field :reported_by_manager_name, :string
    field :reported_by_manager_phone, :string
    field :notes, :string
    field :reported_on, :date
    field :reported_at, :utc_datetime
    field :scooter_id, :id
    field :branch_id, :id

    timestamps(type: :utc_datetime)
  end

  def changeset(report, attrs) do
    report
    |> cast(attrs, [
      :scooter_id,
      :branch_id,
      :reported_by_manager_name,
      :reported_by_manager_phone,
      :notes,
      :reported_on,
      :reported_at
    ])
    |> validate_required([
      :scooter_id,
      :branch_id,
      :notes,
      :reported_on,
      :reported_at
    ])
  end
end
