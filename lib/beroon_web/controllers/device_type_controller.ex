defmodule BeroonWeb.DeviceTypeController do
  use BeroonWeb, :controller

  alias Beroon.Fleet
  alias Beroon.Fleet.DeviceType

  def index(conn, _params) do
    render(conn, :index, device_types: Fleet.list_device_types())
  end

  def new(conn, _params) do
    changeset = Fleet.change_device_type(%DeviceType{})
    render(conn, :new, form: Phoenix.Component.to_form(changeset))
  end

  def create(conn, %{"device_type" => params}) do
    case Fleet.create_device_type(params) do
      {:ok, device_type} ->
        conn
        |> put_flash(:info, "نوع دستگاه ثبت شد.")
        |> redirect(to: ~p"/device_types/#{device_type}")

      {:error, changeset} ->
        render(conn, :new, form: Phoenix.Component.to_form(changeset))
    end
  end

  def show(conn, %{"id" => id}) do
    render(conn, :show, device_type: Fleet.get_device_type!(id))
  end

  def edit(conn, %{"id" => id}) do
    device_type = Fleet.get_device_type!(id)
    changeset = Fleet.change_device_type(device_type)

    render(conn, :edit,
      device_type: device_type,
      form: Phoenix.Component.to_form(changeset)
    )
  end

  def update(conn, %{"id" => id, "device_type" => params}) do
    device_type = Fleet.get_device_type!(id)

    case Fleet.update_device_type(device_type, params) do
      {:ok, device_type} ->
        conn
        |> put_flash(:info, "نوع دستگاه ویرایش شد.")
        |> redirect(to: ~p"/device_types/#{device_type}")

      {:error, changeset} ->
        render(conn, :edit,
          device_type: device_type,
          form: Phoenix.Component.to_form(changeset)
        )
    end
  end

  def delete(conn, %{"id" => id}) do
    device_type = Fleet.get_device_type!(id)
    {:ok, _device_type} = Fleet.delete_device_type(device_type)

    conn
    |> put_flash(:info, "نوع دستگاه حذف شد.")
    |> redirect(to: ~p"/device_types")
  end
end
