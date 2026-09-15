defmodule Beroon.Consumables.Consumable do
  use Ecto.Schema
  import Ecto.Changeset

  schema "consumables" do
    field :name, :string
    field :quantity, :integer, default: 0

    timestamps(type: :utc_datetime)
  end

  def changeset(consumable, attrs) do
    consumable
    |> cast(attrs, [:name, :quantity])
    |> update_change(:name, &(&1 && String.trim(&1)))
    |> validate_required([:name, :quantity])
    |> validate_number(:quantity, greater_than_or_equal_to: 0)
    |> unique_constraint(:name)
  end
end
