defmodule Beroon.Reports.EveningCountItem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "evening_count_items" do
    field :scanned_code, :string
    field :scan_result, :string, default: "expected"
    field :home_branch_id, :id
    field :current_branch_id, :id
    field :evening_count_id, :id
    field :scooter_id, :id

    timestamps(type: :utc_datetime)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [
      :evening_count_id,
      :scooter_id,
      :scanned_code,
      :scan_result,
      :home_branch_id,
      :current_branch_id
    ])
    |> validate_required([:evening_count_id, :scooter_id, :scanned_code, :scan_result])
    |> validate_inclusion(:scan_result, ["expected", "foreign", "transport"])
    |> unique_constraint([:evening_count_id, :scooter_id])
  end
end
