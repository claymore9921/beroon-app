defmodule BeroonWeb.ScooterController do
  use BeroonWeb, :controller

  alias Beroon.Fleet
  alias Beroon.Fleet.Scooter
  alias Beroon.Operations

  def index(conn, params) do
    query = params |> Map.get("q", "") |> String.trim()

    render(conn, :index,
      scooters: Fleet.list_scooters_with_details(query),
      query: query
    )
  end

  def new(conn, _params) do
    changeset = Fleet.change_scooter(%Scooter{})

    render(conn, :new,
      form: Phoenix.Component.to_form(changeset),
      branches: Operations.list_branches(),
      device_types: Fleet.list_device_types()
    )
  end

  def create(conn, %{"scooter" => scooter_params}) do
    case Fleet.create_scooter(scooter_params) do
      {:ok, scooter} ->
        conn
        |> put_flash(:info, "دستگاه ثبت شد.")
        |> redirect(to: ~p"/scooters/#{scooter}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new,
          form: Phoenix.Component.to_form(changeset),
          branches: Operations.list_branches(),
          device_types: Fleet.list_device_types()
        )
    end
  end

  def show(conn, %{"id" => id}) do
    render(conn, :show, scooter: Fleet.get_scooter_with_details!(id))
  end

  def edit(conn, %{"id" => id}) do
    scooter = Fleet.get_scooter_with_details!(id)
    changeset = Fleet.change_scooter(scooter)

    render(conn, :edit,
      scooter: scooter,
      form: Phoenix.Component.to_form(changeset),
      branches: Operations.list_branches(),
      device_types: Fleet.list_device_types()
    )
  end

  def update(conn, %{"id" => id, "scooter" => scooter_params}) do
    scooter = Fleet.get_scooter!(id)

    case Fleet.update_scooter(scooter, scooter_params) do
      {:ok, scooter} ->
        conn
        |> put_flash(:info, "دستگاه ویرایش شد.")
        |> redirect(to: ~p"/scooters/#{scooter}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit,
          scooter: Fleet.get_scooter_with_details!(id),
          form: Phoenix.Component.to_form(changeset),
          branches: Operations.list_branches(),
          device_types: Fleet.list_device_types()
        )
    end
  end

  def delete(conn, %{"id" => id}) do
    scooter = Fleet.get_scooter!(id)
    {:ok, _scooter} = Fleet.delete_scooter(scooter)

    conn
    |> put_flash(:info, "دستگاه حذف شد.")
    |> redirect(to: ~p"/scooters")
  end
end
