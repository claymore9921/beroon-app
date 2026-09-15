defmodule Beroon.Consumables.ConsumableStockMovement do
  use Ecto.Schema
  import Ecto.Changeset

  schema "consumable_stock_movements" do
    field :consumable_name, :string
    field :movement_type, :string
    field :quantity, :integer
    field :registered_by_phone, :string
    field :occurred_at, :utc_datetime
    belongs_to :consumable, Beroon.Consumables.Consumable
    belongs_to :branch, Beroon.Operations.Branch

    timestamps(type: :utc_datetime)
  end

  def changeset(movement, attrs) do
    movement
    |> cast(attrs, [:consumable_id, :consumable_name, :movement_type, :quantity, :branch_id, :registered_by_phone, :occurred_at])
    |> validate_required([:consumable_name, :movement_type, :quantity, :occurred_at])
    |> validate_inclusion(:movement_type, ["consumption", "purchase", "branch_request"])
    |> validate_number(:quantity, greater_than: 0)
  end
end
