defmodule Beroon.Reports.MorningInspection do
  use Ecto.Schema
  import Ecto.Changeset

  schema "morning_inspections" do
    field :checked_on, :date
    field :checked_at, :utc_datetime
    field :manager_name, :string
    field :manager_phone, :string
    field :status, :string
    field :notes, :string
    field :submitted_before_deadline, :boolean, default: false
    field :branch_id, :id
    field :scooter_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(morning_inspection, attrs) do
    morning_inspection
    |> cast(attrs, [
      :checked_on,
      :checked_at,
      :manager_name,
      :manager_phone,
      :status,
      :notes,
      :submitted_before_deadline,
      :branch_id,
      :scooter_id
    ])
    |> validate_required([
      :checked_on,
      :checked_at,
      :manager_name,
      :manager_phone,
      :status,
      :submitted_before_deadline,
      :branch_id,
      :scooter_id
    ])
    |> unique_constraint([:manager_phone, :checked_on, :scooter_id],
      name: :morning_inspections_manager_day_scooter_index
    )
  end
end
