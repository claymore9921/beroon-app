defmodule BeroonWeb.ScooterLookupController do
  use BeroonWeb, :controller

  alias Beroon.Fleet
  alias Beroon.Logistics
  alias Beroon.Operations

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

  # ثبت مشاهده دستگاه در آمار شب و به‌روزرسانی محل فعلی همان لحظه.
  def evening_scan(conn, %{"code" => code}) do
    branch = Operations.get_branch_for_manager_phone(conn.assigns.current_user_phone)
    scooter = Fleet.get_scooter_by_plate_or_barcode(code)

    cond do
      is_nil(branch) ->
        conn |> put_status(:forbidden) |> json(%{error: "branch_not_found"})

      is_nil(scooter) ->
        conn |> put_status(:not_found) |> json(%{error: "not_found"})

      scooter.status in ["loaned", "stolen"] ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: scooter.status})

      true ->
        # مطابق منطق آمار شب، مشاهده فیزیکی دستگاه ملاک است: محل فعلی به
        # شعبه اسکن‌کننده منتقل و دستگاه فعال می‌شود. اگر دستگاه متعلق به
        # شعبه دیگری باشد، برای همان شعبه مالک «جابجا شده» محسوب می‌شود.
        _ = Logistics.mark_evening_seen(scooter, branch.id)
        updated = Fleet.get_scooter_by_plate_or_barcode(code)
        json(conn, %{scooter: updated, moved_from_owner: updated.branch_id != branch.id})
    end
  end
end
