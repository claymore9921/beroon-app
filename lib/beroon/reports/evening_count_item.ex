defmodule Beroon.Reports.EveningCountItem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "evening_count_items" do
    field :scanned_code, :string
    field :evening_count_id, :id
    field :scooter_id, :id

    timestamps(type: :utc_datetime)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:evening_count_id, :scooter_id, :scanned_code])
    |> validate_required([:evening_count_id, :scooter_id, :scanned_code])
    |> unique_constraint([:evening_count_id, :scooter_id])
  end
end
