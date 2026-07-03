defmodule Beroon.Reports.ScooterLocationAlert do
  use Ecto.Schema
  import Ecto.Changeset

  schema "scooter_location_alerts" do
    field :detected_on, :date
    field :detected_at, :utc_datetime
    field :detected_by_manager_name, :string
    field :detected_by_manager_phone, :string
    field :resolved, :boolean, default: false
    field :scooter_id, :id
    field :home_branch_id, :id
    field :detected_branch_id, :id
    field :evening_count_id, :id

    timestamps(type: :utc_datetime)
  end

  def changeset(alert, attrs) do
    alert
    |> cast(attrs, [
      :scooter_id,
      :home_branch_id,
      :detected_branch_id,
      :evening_count_id,
      :detected_on,
      :detected_at,
      :detected_by_manager_name,
      :detected_by_manager_phone,
      :resolved
    ])
    |> validate_required([
      :scooter_id,
      :home_branch_id,
      :detected_branch_id,
      :evening_count_id,
      :detected_on,
      :detected_at,
      :resolved
    ])
    |> unique_constraint([:scooter_id, :home_branch_id, :detected_branch_id, :detected_on],
      name: :scooter_location_alerts_unique_daily_mismatch_index
    )
  end
end
