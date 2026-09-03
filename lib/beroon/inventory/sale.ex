defmodule Beroon.Inventory.Sale do
  use Ecto.Schema
  import Ecto.Changeset
  alias Beroon.Fleet.DeviceType
  schema "new_device_sales" do
    belongs_to :device_type, DeviceType
    field :quantity, :integer
    field :unit_price, :integer
    field :sold_at, :utc_datetime
    field :sold_by_phone, :string
    field :notes, :string
    timestamps(type: :utc_datetime)
  end
  def changeset(sale, attrs) do
    sale |> cast(attrs, [:device_type_id,:quantity,:unit_price,:sold_at,:sold_by_phone,:notes]) |> validate_required([:device_type_id,:quantity,:unit_price,:sold_at]) |> validate_number(:quantity, greater_than: 0) |> validate_number(:unit_price, greater_than_or_equal_to: 0)
  end
end
