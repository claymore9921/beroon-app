defmodule Beroon.Parts.PartStockMovement do
  use Ecto.Schema
  import Ecto.Changeset

  schema "part_stock_movements" do
    field :part_name, :string
    field :movement_type, :string
    field :quantity, :integer
    field :registered_by_phone, :string
    field :occurred_at, :utc_datetime
    belongs_to :part, Beroon.Parts.Part

    timestamps(type: :utc_datetime)
  end

  def changeset(movement, attrs) do
    movement
    |> cast(attrs, [:part_id, :part_name, :movement_type, :quantity, :registered_by_phone, :occurred_at])
    |> validate_required([:part_name, :movement_type, :quantity, :occurred_at])
    |> validate_inclusion(:movement_type, ["consumption", "purchase"])
    |> validate_number(:quantity, greater_than: 0)
  end
end
