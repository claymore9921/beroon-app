defmodule Beroon.Consumables.ConsumableRequestItem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "consumable_request_items" do
    field :consumable_name, :string
    field :quantity, :integer
    belongs_to :consumable, Beroon.Consumables.Consumable
    belongs_to :consumable_request, Beroon.Consumables.ConsumableRequest

    timestamps(type: :utc_datetime)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:consumable_request_id, :consumable_id, :consumable_name, :quantity])
    |> validate_required([:consumable_request_id, :consumable_name, :quantity])
    |> validate_number(:quantity, greater_than: 0)
  end
end
