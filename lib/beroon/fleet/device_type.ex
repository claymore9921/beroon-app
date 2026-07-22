defmodule Beroon.Fleet.DeviceType do
  use Ecto.Schema
  import Ecto.Changeset

  schema "device_types" do
    has_one :new_device_stock, Beroon.Inventory.NewDeviceStock
    field :name, :string
    field :code, :string
    field :device_identifier, :string
    field :category, :string
    field :device_model, :string
    field :description, :string
    field :active, :boolean, default: true

    timestamps(type: :utc_datetime)
  end

  def changeset(device_type, attrs) do
    attrs = normalize_attrs(attrs)

    device_type
    |> cast(attrs, [
      :name,
      :code,
      :device_identifier,
      :category,
      :device_model,
      :description,
      :active
    ])
    |> validate_required([:device_identifier, :category, :device_model, :active])
    |> unique_constraint(:code)
    |> unique_constraint(:device_identifier)
  end

  defp normalize_attrs(attrs) do
    attrs = Map.new(attrs, fn {key, value} -> {to_string(key), value} end)

    attrs =
      attrs
      |> Map.put_new("device_identifier", attrs["code"])
      |> Map.put_new("device_model", attrs["name"])

    attrs
    |> Map.put("code", attrs["device_identifier"])
    |> Map.put("name", attrs["device_model"])
  end
end
