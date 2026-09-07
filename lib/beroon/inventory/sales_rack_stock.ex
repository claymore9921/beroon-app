defmodule Beroon.Inventory.SalesRackStock do
  use Ecto.Schema
  import Ecto.Changeset

  alias Beroon.Fleet.DeviceType
  alias Beroon.Operations.Branch

  schema "sales_rack_stocks" do
    belongs_to :device_type, DeviceType
    belongs_to :branch, Branch
    field :quantity, :integer, default: 0
    timestamps(type: :utc_datetime)
  end

  def changeset(stock, attrs) do
    stock
    |> cast(attrs, [:device_type_id, :branch_id, :quantity])
    |> validate_required([:device_type_id, :branch_id, :quantity])
    |> validate_number(:quantity, greater_than_or_equal_to: 0)
    |> unique_constraint([:device_type_id, :branch_id])
  end
end
