defmodule Beroon.Reports.EveningCount do
  use Ecto.Schema
  import Ecto.Changeset

  schema "evening_counts" do
    field :counted_on, :date
    field :counted_at, :utc_datetime
    field :manager_name, :string
    field :manager_phone, :string
    field :total_count, :integer
    field :available_count, :integer
    field :rented_count, :integer
    field :damaged_count, :integer
    field :missing_count, :integer
    field :notes, :string
    field :expected_scooter_ids, {:array, :integer}, default: []
    field :branch_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(evening_count, attrs) do
    evening_count
    |> cast(attrs, [
      :counted_on,
      :counted_at,
      :manager_name,
      :manager_phone,
      :total_count,
      :available_count,
      :rented_count,
      :damaged_count,
      :missing_count,
      :notes,
      :expected_scooter_ids,
      :branch_id
    ])
    |> validate_required([
      :counted_on,
      :counted_at,
      :manager_name,
      :manager_phone,
      :total_count,
      :available_count,
      :rented_count,
      :damaged_count,
      :missing_count,
      :branch_id
    ])
    |> validate_number(:total_count, greater_than_or_equal_to: 0)
    |> validate_number(:available_count, greater_than_or_equal_to: 0)
    |> validate_number(:rented_count, greater_than_or_equal_to: 0)
    |> validate_number(:damaged_count, greater_than_or_equal_to: 0)
    |> validate_number(:missing_count, greater_than_or_equal_to: 0)
  end
end
