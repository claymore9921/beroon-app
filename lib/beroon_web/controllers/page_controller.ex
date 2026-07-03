defmodule BeroonWeb.PageController do
  use BeroonWeb, :controller

  alias Beroon.Checklists
  alias Beroon.Fleet
  alias Beroon.Operations
  alias Beroon.Reports

  def home(conn, _params) do
    case conn.assigns[:current_user_role] do
      "admin" -> redirect(conn, to: ~p"/admin/reports")
      "branch_manager" -> redirect(conn, to: ~p"/manager")
      "branch_manager_pending" -> redirect(conn, to: ~p"/manager/pending")
      _ -> redirect(conn, to: ~p"/login")
    end
  end

  def manager_home(conn, _params) do
    today = Date.utc_today()
    branch = Operations.get_branch_for_manager_phone(conn.assigns.current_user_phone)

    if is_nil(branch) do
      redirect(conn, to: ~p"/manager/pending")
    else
      render(conn, :manager_home,
        branch: branch,
        manager_name: manager_name(branch),
        location_alerts: branch_location_alerts(branch),
        persian_today: Beroon.Calendar.persian_date(today),
        morning_submitted:
          Reports.morning_submitted_today?(conn.assigns.current_user_phone, today),
        evening_submitted:
          Reports.evening_submitted_today?(conn.assigns.current_user_phone, today)
      )
    end
  end

  def manager_pending(conn, _params) do
    render(conn, :manager_pending, phone: conn.assigns.current_user_phone)
  end

  def manager_scooters(conn, params) do
    branch = Operations.get_branch_for_manager_phone(conn.assigns.current_user_phone)
    status = params["status"]

    if is_nil(branch) do
      redirect(conn, to: ~p"/manager/pending")
    else
      render(conn, :manager_scooters,
        branch: branch,
        status: status,
        title: manager_scooters_title(status),
        scooters: Fleet.list_scooters_for_branch_with_details(branch.id, status),
        persian_today: Beroon.Calendar.persian_date(Date.utc_today())
      )
    end
  end

  def manager_morning(conn, params) do
    branch = Operations.get_branch_for_manager_phone(conn.assigns.current_user_phone)
    code = params |> Map.get("code", "") |> String.trim()
    selected_scooter = selected_morning_scooter(branch, code)

    if is_nil(branch) do
      redirect(conn, to: ~p"/manager/pending")
    else
      render(conn, :manager_morning,
        branch: branch,
        manager_name: manager_name(branch),
        checklist_items: Checklists.list_active_checklist_items(),
        selected_code: code,
        selected_scooter: selected_scooter,
        selected_submitted:
          selected_scooter &&
            Reports.morning_scooter_submitted_today?(
              conn.assigns.current_user_phone,
              selected_scooter.id
            ),
        persian_today: Beroon.Calendar.persian_date(Date.utc_today())
      )
    end
  end

  def submit_morning(conn, %{"morning" => params}) do
    branch = Operations.get_branch_for_manager_phone(conn.assigns.current_user_phone)
    scooter = branch && Fleet.get_scooter_for_branch_with_details(branch.id, params["scooter_id"])

    cond do
      is_nil(branch) ->
        conn
        |> put_flash(:error, "شعبه‌ای برای این مدیر پیدا نشد.")
        |> redirect(to: ~p"/manager/morning")

      is_nil(scooter) ->
        conn
        |> put_flash(:error, "این دستگاه در شعبه شما پیدا نشد.")
        |> redirect(to: ~p"/manager/morning")

      Reports.morning_scooter_submitted_today?(conn.assigns.current_user_phone, scooter.id) ->
        conn
        |> put_flash(:error, "چک‌لیست این دستگاه امروز قبلا ثبت شده است.")
        |> redirect(to: ~p"/manager/morning")

      true ->
        do_submit_morning(conn, params, branch, scooter)
    end
  end

  defp do_submit_morning(conn, params, branch, scooter) do
    checklist_item_ids = List.wrap(params["checklist_item_ids"])
    checked_item_ids = List.wrap(params["checked_item_ids"])
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    all_checked? = Enum.sort(checklist_item_ids) == Enum.sort(checked_item_ids)

    attrs =
      params
      |> Map.take(["notes"])
      |> Map.merge(%{
        "manager_name" => manager_name(branch),
        "branch_id" => branch.id,
        "scooter_id" => scooter.id,
        "checked_on" => Date.utc_today(),
        "checked_at" => now,
        "status" => if(all_checked?, do: "ready", else: "needs_service"),
        "manager_phone" => conn.assigns.current_user_phone,
        "submitted_before_deadline" => before_11_tehran?(now)
      })

    case Reports.create_morning_inspection_with_items(attrs, checklist_item_ids, checked_item_ids) do
      {:ok, _inspection} ->
        conn
        |> put_flash(:info, "چک‌لیست پلاک #{scooter.plate} ثبت شد. دستگاه بعدی را اسکن کنید.")
        |> redirect(to: ~p"/manager/morning")

      {:error, changeset} ->
        conn
        |> put_flash(:error, "گزارش ثبت نشد: #{first_error(changeset)}")
        |> redirect(to: ~p"/manager/morning")
    end
  end

  def manager_evening(conn, _params) do
    branch = Operations.get_branch_for_manager_phone(conn.assigns.current_user_phone)

    if is_nil(branch) do
      redirect(conn, to: ~p"/manager/pending")
    else
      render(conn, :manager_evening,
        branches: [branch],
        submitted: Reports.evening_submitted_today?(conn.assigns.current_user_phone),
        persian_today: Beroon.Calendar.persian_date(Date.utc_today())
      )
    end
  end

  def submit_evening(conn, %{"evening" => params}) do
    if Reports.evening_submitted_today?(conn.assigns.current_user_phone) do
      conn
      |> put_flash(:error, "آمار شب امروز قبلا ثبت شده است.")
      |> redirect(to: ~p"/manager/evening")
    else
      do_submit_evening(conn, params)
    end
  end

  defp do_submit_evening(conn, params) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    scanned_codes =
      params |> Map.get("scanned_codes", []) |> List.wrap() |> Enum.reject(&(&1 == ""))

    scanned_scooters =
      Enum.map(scanned_codes, &Fleet.get_scooter_by_plate_or_barcode/1) |> Enum.reject(&is_nil/1)

    total_count = length(Enum.uniq_by(scanned_scooters, & &1.id))

    attrs =
      params
      |> Map.take(["branch_id", "manager_name", "notes"])
      |> Map.merge(%{
        "manager_phone" => conn.assigns.current_user_phone,
        "total_count" => total_count,
        "available_count" => total_count,
        "rented_count" => 0,
        "damaged_count" => 0,
        "missing_count" => 0,
        "counted_on" => Date.utc_today(),
        "counted_at" => now
      })

    case Reports.create_evening_count_with_items(attrs, scanned_scooters) do
      {:ok, _count} ->
        conn
        |> put_flash(:info, "آمار شب با مجموع #{total_count} دستگاه ثبت شد.")
        |> redirect(to: ~p"/manager/evening")

      {:error, changeset} ->
        conn
        |> put_flash(:error, "آمار ثبت نشد: #{first_error(changeset)}")
        |> redirect(to: ~p"/manager/evening")
    end
  end

  def admin_reports(conn, params) do
    date = parse_date(params["date"])

    render(conn, :admin_reports,
      date: date,
      morning_reports: Reports.list_morning_inspections_for_date(date),
      evening_reports: Reports.list_evening_counts_for_date(date),
      location_alerts: Reports.list_location_alerts_for_date(date)
    )
  end

  def admin_manager_registrations(conn, _params) do
    render(conn, :admin_manager_registrations,
      registrations: Operations.list_pending_manager_registrations(),
      branches: Operations.list_active_branches()
    )
  end

  def approve_manager_registration(conn, %{"id" => id, "manager" => %{"branch_id" => branch_id}}) do
    case Operations.approve_manager_registration(id, branch_id) do
      {:ok, _registration} ->
        conn
        |> put_flash(:info, "مدیر شعبه تایید و به شعبه اختصاص داده شد.")
        |> redirect(to: ~p"/admin/managers")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "تایید مدیر انجام نشد.")
        |> redirect(to: ~p"/admin/managers")
    end
  end

  def admin_checklist_branches(conn, _params) do
    render(conn, :admin_checklist_branches,
      branches: Operations.list_branches(),
      date: Date.utc_today()
    )
  end

  def admin_branch_checklists(conn, %{"id" => id} = params) do
    branch = Operations.get_branch!(id)
    date = parse_date(params["date"])
    query = params |> Map.get("q", "") |> String.trim()

    render(conn, :admin_branch_checklists,
      branch: branch,
      date: date,
      query: query,
      reports: Reports.list_morning_inspections_for_branch(date, branch.id, query),
      unchecked_count: Reports.count_unchecked_scooters_for_branch(date, branch.id)
    )
  end

  def admin_branch_unchecked_scooters(conn, %{"id" => id} = params) do
    branch = Operations.get_branch!(id)
    date = parse_date(params["date"])
    query = params |> Map.get("q", "") |> String.trim()

    render(conn, :admin_branch_unchecked_scooters,
      branch: branch,
      date: date,
      query: query,
      scooters: Reports.list_unchecked_scooters_for_branch(date, branch.id, query)
    )
  end

  defp selected_morning_scooter(nil, _code), do: nil
  defp selected_morning_scooter(_branch, ""), do: nil

  defp selected_morning_scooter(branch, code) do
    Fleet.get_scooter_by_plate_or_barcode_with_details(branch.id, code)
  end

  defp parse_date(nil), do: Date.utc_today()
  defp parse_date(""), do: Date.utc_today()

  defp parse_date(date) do
    case Date.from_iso8601(date) do
      {:ok, parsed} -> parsed
      _ -> Date.utc_today()
    end
  end

  defp before_11_tehran?(%DateTime{} = utc_now) do
    time =
      utc_now
      |> DateTime.add(3 * 3600 + 30 * 60, :second)
      |> DateTime.to_time()

    Time.compare(time, ~T[11:00:00]) in [:lt, :eq]
  end

  defp first_error(changeset) do
    changeset.errors
    |> List.first()
    |> case do
      {field, {message, _}} -> "#{field} #{message}"
      _ -> "ورودی‌ها را بررسی کنید"
    end
  end

  defp manager_name(nil), do: "مدیر"
  defp manager_name(branch), do: branch.manager_name || "مدیر"

  defp branch_location_alerts(nil), do: []

  defp branch_location_alerts(branch),
    do: Reports.list_open_location_alerts_for_home_branch(branch.id)

  defp manager_scooters_title("active"), do: "دستگاه‌های فعال"
  defp manager_scooters_title("needs_service"), do: "دستگاه‌های نیازمند تعمیر"
  defp manager_scooters_title("waiting_for_part"), do: "دستگاه‌های در انتظار قطعه"
  defp manager_scooters_title("out_of_service"), do: "دستگاه‌های از مدار خارج شده"
  defp manager_scooters_title(_status), do: "لیست دستگاه‌های شعبه من"
end
