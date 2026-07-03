defmodule BeroonWeb.ScooterLookupController do
  use BeroonWeb, :controller

  alias Beroon.Fleet

  def show(conn, %{"code" => code}) do
    case Fleet.get_scooter_by_plate_or_barcode(code) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found"})

      scooter ->
        json(conn, %{scooter: scooter})
    end
  end
end
