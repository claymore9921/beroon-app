defmodule Beroon.Parts.Part do
  use Ecto.Schema
  import Ecto.Changeset

  schema "parts" do
    field :name, :string
    field :quantity, :integer, default: 0

    timestamps(type: :utc_datetime)
  end

  def changeset(part, attrs) do
    part
    |> cast(attrs, [:name, :quantity])
    |> update_change(:name, &(&1 && String.trim(&1)))
    |> validate_required([:name, :quantity])
    |> validate_number(:quantity, greater_than_or_equal_to: 0)
    |> unique_constraint(:name)
  end
end
