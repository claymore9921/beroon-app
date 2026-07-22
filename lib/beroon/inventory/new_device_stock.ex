defmodule Beroon.Inventory.NewDeviceStock do
  use Ecto.Schema
  import Ecto.Changeset
  alias Beroon.Fleet.DeviceType
  schema "new_device_stocks" do
    belongs_to :device_type, DeviceType
    field :quantity, :integer, default: 0
    timestamps(type: :utc_datetime)
  end
  def changeset(stock, attrs) do
    stock |> cast(attrs, [:device_type_id,:quantity]) |> validate_required([:device_type_id,:quantity]) |> validate_number(:quantity, greater_than_or_equal_to: 0) |> unique_constraint(:device_type_id)
  end
end
