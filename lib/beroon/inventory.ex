defmodule Beroon.Inventory do
  import Ecto.Query
  alias Ecto.Multi
  alias Beroon.Repo
  alias Beroon.Fleet.DeviceType
  alias Beroon.Inventory.{NewDeviceStock,Sale}

  def list_stocks do
    DeviceType |> where([d], d.active==true) |> order_by([d], asc: d.category, asc: d.device_model) |> preload([d], [:new_device_stock]) |> Repo.all()
  end
  def list_sales do
    Sale |> order_by([s], desc: s.sold_at) |> preload(:device_type) |> limit(100) |> Repo.all()
  end
  def set_stock(device_type_id, quantity) do
    attrs=%{device_type_id: device_type_id, quantity: quantity}
    case Repo.get_by(NewDeviceStock, device_type_id: device_type_id) do
      nil -> %NewDeviceStock{} |> NewDeviceStock.changeset(attrs) |> Repo.insert()
      stock -> stock |> NewDeviceStock.changeset(attrs) |> Repo.update()
    end
  end
  def create_sale(attrs) do
    qty = to_int(attrs["quantity"] || attrs[:quantity])
    type_id = to_int(attrs["device_type_id"] || attrs[:device_type_id])
    Multi.new()
    |> Multi.run(:stock, fn repo,_ ->
      case repo.get_by(NewDeviceStock, device_type_id: type_id) do
        %NewDeviceStock{quantity: q}=s when q>=qty -> {:ok,s}
        _ -> {:error,:insufficient_stock}
      end
    end)
    |> Multi.insert(:sale, Sale.changeset(%Sale{}, Map.merge(Map.new(attrs), %{"quantity"=>qty,"device_type_id"=>type_id})))
    |> Multi.update(:decrement, fn %{stock: s} -> NewDeviceStock.changeset(s,%{quantity: s.quantity-qty}) end)
    |> Repo.transaction()
  end
  defp to_int(v) when is_integer(v), do: v
  defp to_int(v) when is_binary(v) do
    case Integer.parse(v) do
      {integer, _rest} -> integer
      :error -> 0
    end
  end
  defp to_int(_), do: 0
end
