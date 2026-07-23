defmodule BeroonWeb.ScooterLookupController do
  use BeroonWeb, :controller

  alias Beroon.Fleet
  alias Beroon.Logistics

  def show(conn, %{"code" => code}) do
    case Fleet.get_scooter_by_plate_or_barcode(code) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found"})

      scooter ->
        scooter = Logistics.refresh_expired_transport(scooter)
        json(conn, %{scooter: scooter})
    end
  end
end
