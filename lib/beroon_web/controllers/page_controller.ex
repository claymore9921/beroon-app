defmodule BeroonWeb.PageController do
  use BeroonWeb, :controller

  alias Beroon.Checklists
  alias Beroon.Fleet
  alias Beroon.Operations
  alias Beroon.Reports

  @manager_workshop_statuses ["awaiting_repair", "repairing"]

  def home(conn, _params) do
    case conn.assigns[:current_user_role] do
      "admin" -> redirect(conn, to: ~p"/admin/reports")
      "branch_manager" -> redirect(conn, to: ~p"/manager")
      "workshop_manager" -> redirect(conn, to: ~p"/workshop")
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
        scooter_counts: manager_scooter_counts(branch.id),
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
        scooters: manager_scooters_for_status(branch.id, status),
        persian_today: Beroon.Calendar.persian_date(Date.utc_today())
      )
    end
  end

  def manager_repairs(conn, params) do
    branch = Operations.get_branch_for_manager_phone(conn.assigns.current_user_phone)
    query = params |> Map.get("q", "") |> String.trim()

    if is_nil(branch) do
      redirect(conn, to: ~p"/manager/pending")
    else
      render(conn, :manager_repairs,
        branch: branch,
        query: query,
        scooters: Fleet.list_scooters_for_branch_search(branch.id, query, "active"),
        ready_for_pickup_scooters:
          Fleet.list_scooters_for_branch_with_details(branch.id, "ready_for_pickup"),
        persian_today: Beroon.Calendar.persian_date(Date.utc_today())
      )
    end
  end

  def send_scooter_to_workshop(conn, %{"id" => id, "repair" => %{"notes" => notes}}) do
    branch = Operations.get_branch_for_manager_phone(conn.assigns.current_user_phone)
    notes = String.trim(to_string(notes || ""))
    scooter = branch && Fleet.get_scooter_for_branch_with_details(branch.id, id)

    cond do
      is_nil(branch) ->
        redirect(conn, to: ~p"/manager/pending")

      is_nil(scooter) ->
        conn
        |> put_flash(:error, "این دستگاه در شعبه شما پیدا نشد.")
        |> redirect(to: ~p"/manager/repairs")

      notes == "" ->
        conn
        |> put_flash(:error, "توضیحات خرابی اجباری است.")
        |> redirect(to: ~p"/manager/repairs?q=#{scooter.plate}")

      true ->
        {:ok, _scooter} = Fleet.update_scooter(scooter, %{status: "needs_service", notes: notes})

        conn
        |> put_flash(:info, "دستگاه به لیست تعمیرگاه ارسال شد.")
        |> redirect(to: ~p"/manager/repairs?q=#{scooter.plate}")
    end
  end

  def manager_repair_receive(conn, _params) do
    branch = Operations.get_branch_for_manager_phone(conn.assigns.current_user_phone)

    if is_nil(branch) do
      redirect(conn, to: ~p"/manager/pending")
    else
      render(conn, :manager_repair_receive,
        branch: branch,
        plate: "",
        persian_today: Beroon.Calendar.persian_date(Date.utc_today())
      )
    end
  end

  def receive_repaired_scooter(conn, %{"receive" => %{"plate" => plate}}) do
    branch = Operations.get_branch_for_manager_phone(conn.assigns.current_user_phone)
    plate = String.trim(to_string(plate || ""))
    scooter = branch && Fleet.get_scooter_by_plate_or_barcode_with_details(branch.id, plate)

    cond do
      is_nil(branch) ->
        redirect(conn, to: ~p"/manager/pending")

      plate == "" ->
        conn
        |> put_flash(:error, "پلاک دستگاه را وارد کنید.")
        |> render(:manager_repair_receive,
          branch: branch,
          plate: plate,
          persian_today: Beroon.Calendar.persian_date(Date.utc_today())
        )

      is_nil(scooter) ->
        conn
        |> put_flash(:error, "دستگاهی با این پلاک در شعبه شما پیدا نشد.")
        |> render(:manager_repair_receive,
          branch: branch,
          plate: plate,
          persian_today: Beroon.Calendar.persian_date(Date.utc_today())
        )

      scooter.status == "ready_for_pickup" ->
        {:ok, _scooter} = Fleet.update_scooter(scooter, %{status: "active", notes: nil})

        conn
        |> put_flash(:info, "تحویل دستگاه از تعمیرگاه ثبت شد.")
        |> redirect(to: ~p"/manager/repairs/receive")

      true ->
        conn
        |> put_flash(:error, "این دستگاه هنوز آماده تحویل نیست.")
        |> render(:manager_repair_receive,
          branch: branch,
          plate: plate,
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

  def workshop_home(conn, _params) do
    workshop = Operations.get_workshop_for_manager_phone(conn.assigns.current_user_phone)

    if is_nil(workshop) do
      conn
      |> put_flash(:error, "دسترسی تعمیرگاه برای این شماره فعال نیست.")
      |> redirect(to: ~p"/manager/pending")
    else
      render(conn, :workshop_home,
        workshop: workshop,
        acceptance_count: length(Fleet.list_scooters_by_statuses(["needs_service"])),
        repairing_count:
          length(
            Fleet.list_scooters_by_statuses(["awaiting_repair", "repairing", "waiting_for_part"])
          ),
        discharge_count:
          length(Fleet.list_scooters_by_statuses(["repairing", "waiting_for_part"]))
      )
    end
  end

  def workshop_acceptance(conn, params) do
    render_workshop_section(conn, params, :workshop_acceptance, ["needs_service"])
  end

  def workshop_repairing(conn, params) do
    render_workshop_section(conn, params, :workshop_repairing, [
      "awaiting_repair",
      "repairing",
      "waiting_for_part"
    ])
  end

  def workshop_discharge(conn, params) do
    render_workshop_section(conn, params, :workshop_discharge, ["repairing", "waiting_for_part"])
  end

  def workshop_accept_scooter(conn, %{"id" => id}) do
    with %{} = workshop <-
           Operations.get_workshop_for_manager_phone(conn.assigns.current_user_phone),
         scooter <- Fleet.get_scooter_with_details!(id),
         true <- scooter.status == "needs_service",
         {:ok, _scooter} <- Fleet.update_scooter(scooter, %{status: "awaiting_repair"}) do
      conn
      |> put_flash(:info, "پذیرش دستگاه در #{workshop.name} ثبت شد.")
      |> redirect(to: ~p"/workshop/acceptance")
    else
      _ ->
        conn
        |> put_flash(:error, "پذیرش دستگاه انجام نشد.")
        |> redirect(to: ~p"/workshop/acceptance")
    end
  end

  def workshop_start_repair(conn, %{"id" => id}) do
    workshop_update_status(
      conn,
      id,
      "repairing",
      "دستگاه وارد مرحله تعمیر شد.",
      %{},
      ~p"/workshop/repairing"
    )
  end

  def workshop_waiting_part(conn, %{"id" => id}) do
    scooter = Fleet.get_scooter!(id)
    notes = scooter.notes || "در انتظار قطعه"

    workshop_update_status(
      conn,
      id,
      "waiting_for_part",
      "وضعیت دستگاه در انتظار قطعه شد.",
      %{notes: notes},
      ~p"/workshop/repairing"
    )
  end

  def workshop_discharge_scooter(conn, %{"id" => id}) do
    workshop_update_status(
      conn,
      id,
      "ready_for_pickup",
      "دستگاه آماده تحویل شد.",
      %{},
      ~p"/workshop/discharge"
    )
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

  def admin_reports(conn, _params) do
    date = Date.utc_today()

    render(conn, :admin_reports,
      scooter_counts: admin_scooter_counts(),
      location_alerts: Reports.list_open_location_alerts_for_date(date)
    )
  end

  def admin_location_alerts(conn, params) do
    date = parse_date(params["date"])

    render(conn, :admin_location_alerts,
      date: date,
      alert_dates: Reports.list_location_alert_dates(),
      alerts: Reports.list_location_alerts_for_date(date)
    )
  end

  def admin_evening_report_branches(conn, _params) do
    render(conn, :admin_evening_report_branches, branches: Operations.list_branches())
  end

  def admin_branch_evening_reports(conn, %{"id" => id} = params) do
    branch = Operations.get_branch!(id)
    filter_dates = Reports.list_evening_report_dates_for_branch(branch.id)
    selected_date = parse_optional_date(params["date"])

    render(conn, :admin_branch_evening_reports,
      branch: branch,
      filter_dates: filter_dates,
      selected_date: selected_date,
      reports: Reports.list_evening_counts_for_branch(branch.id, selected_date)
    )
  end

  def admin_evening_report_detail(conn, %{"id" => id}) do
    report = Reports.get_evening_count_report!(id)
    branch = Operations.get_branch!(report.branch_id)

    render(conn, :admin_evening_report_detail,
      branch: branch,
      report: report
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

  defp parse_optional_date(nil), do: nil
  defp parse_optional_date(""), do: nil

  defp parse_optional_date(date) do
    case Date.from_iso8601(date) do
      {:ok, parsed} -> parsed
      _ -> nil
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

  defp manager_scooter_counts(branch_id) do
    by_status = Fleet.count_scooters_for_branch_by_status(branch_id)

    %{
      all: Enum.sum(Map.values(by_status)),
      active: Map.get(by_status, "active", 0),
      needs_service: Map.get(by_status, "needs_service", 0),
      awaiting_repair: Map.get(by_status, "awaiting_repair", 0),
      workshop: Enum.sum(Enum.map(@manager_workshop_statuses, &Map.get(by_status, &1, 0))),
      waiting_for_part: Map.get(by_status, "waiting_for_part", 0),
      out_of_service: Map.get(by_status, "out_of_service", 0)
    }
  end

  defp manager_scooters_for_status(branch_id, "workshop"),
    do: Fleet.list_scooters_for_branch_by_statuses(branch_id, @manager_workshop_statuses)

  defp manager_scooters_for_status(branch_id, status),
    do: Fleet.list_scooters_for_branch_with_details(branch_id, status)

  defp admin_scooter_counts do
    by_status = Fleet.count_scooters_by_status()

    %{
      active: Map.get(by_status, "active", 0),
      needs_service: Map.get(by_status, "needs_service", 0),
      awaiting_repair: Map.get(by_status, "awaiting_repair", 0),
      repairing: Map.get(by_status, "repairing", 0),
      waiting_for_part: Map.get(by_status, "waiting_for_part", 0),
      ready_for_pickup: Map.get(by_status, "ready_for_pickup", 0),
      out_of_service: Map.get(by_status, "out_of_service", 0)
    }
  end

  defp render_workshop_section(conn, params, template, statuses) do
    workshop = Operations.get_workshop_for_manager_phone(conn.assigns.current_user_phone)
    query = params |> Map.get("q", "") |> String.trim()

    if is_nil(workshop) do
      conn
      |> put_flash(:error, "دسترسی تعمیرگاه برای این شماره فعال نیست.")
      |> redirect(to: ~p"/manager/pending")
    else
      render(conn, template,
        workshop: workshop,
        query: query,
        scooters: Fleet.list_scooters_by_statuses(statuses, query)
      )
    end
  end

  defp workshop_update_status(conn, id, status, message, extra_attrs, redirect_path) do
    if Operations.get_workshop_for_manager_phone(conn.assigns.current_user_phone) do
      scooter = Fleet.get_scooter!(id)
      attrs = Map.merge(%{status: status}, extra_attrs)

      case Fleet.update_scooter(scooter, attrs) do
        {:ok, _scooter} ->
          conn
          |> put_flash(:info, message)
          |> redirect(to: redirect_path)

        {:error, _changeset} ->
          conn
          |> put_flash(:error, "تغییر وضعیت دستگاه انجام نشد.")
          |> redirect(to: redirect_path)
      end
    else
      conn
      |> put_flash(:error, "دسترسی تعمیرگاه برای این شماره فعال نیست.")
      |> redirect(to: ~p"/manager/pending")
    end
  end

  defp manager_scooters_title("active"), do: "دستگاه‌های فعال"

  defp manager_scooters_title("needs_service"),
    do: "دستگاه‌های نیازمند تعمیر"

  defp manager_scooters_title("awaiting_repair"),
    do: "دستگاه‌های در انتظار تعمیر"

  defp manager_scooters_title("workshop"),
    do: "دستگاه‌های تعمیرگاه"

  defp manager_scooters_title("waiting_for_part"),
    do: "دستگاه‌های در انتظار قطعه"

  defp manager_scooters_title("out_of_service"),
    do: "دستگاه‌های از مدار خارج شده"

  defp manager_scooters_title(_status), do: "لیست دستگاه‌های شعبه من"
end
