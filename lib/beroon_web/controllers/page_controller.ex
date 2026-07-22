defmodule BeroonWeb.PageController do
  use BeroonWeb, :controller

  alias Beroon.Checklists
  alias Beroon.Fleet
  alias Beroon.Logistics
  alias Beroon.Inventory
  alias Beroon.Operations
  alias Beroon.Repo
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
    today = Reports.iran_today()
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
          Reports.morning_submitted_today?(branch.id, today),
        evening_submitted:
          Reports.evening_submission_locked?(branch.id)
      )
    end
  end

  def manager_pending(conn, _params) do
    render(conn, :manager_pending, phone: conn.assigns.current_user_phone)
  end

  def manager_notifications(conn, _params) do
    branch = Operations.get_branch_for_manager_phone(conn.assigns.current_user_phone)

    if is_nil(branch) do
      redirect(conn, to: ~p"/manager/pending")
    else
      render(conn, :manager_notifications,
        branch: branch,
        notifications: Reports.list_branch_notifications(branch.id)
      )
    end
  end

  def manager_notification_detail(conn, %{"id" => id}) do
    branch = Operations.get_branch_for_manager_phone(conn.assigns.current_user_phone)

    if is_nil(branch) do
      redirect(conn, to: ~p"/manager/pending")
    else
      Reports.mark_branch_notification_read(branch.id, id)

      render(conn, :manager_notification_detail,
        branch: branch,
        notification: Reports.get_branch_notification_for_recipient!(branch.id, id)
      )
    end
  end

  def manager_scan(conn, _params) do
    today = Reports.iran_today()
    branch = Operations.get_branch_for_manager_phone(conn.assigns.current_user_phone)

    if is_nil(branch) do
      redirect(conn, to: ~p"/manager/pending")
    else
      render(conn, :manager_scan,
        branch: branch,
        manager_name: manager_name(branch),
        persian_today: Beroon.Calendar.persian_date(today),
        morning_submitted:
          Reports.morning_submitted_today?(branch.id, today),
        evening_submitted:
          Reports.evening_submission_locked?(branch.id)
      )
    end
  end

  def manager_scooters(conn, params) do
    branch = Operations.get_branch_for_manager_phone(conn.assigns.current_user_phone)
    status = params["status"]

    if is_nil(branch) do
      redirect(conn, to: ~p"/manager/pending")
    else
      scooters = manager_scooters_for_status(branch.id, status)

      render(conn, :manager_scooters,
        branch: branch,
        status: status,
        title: manager_scooters_title(status),
        scooters: scooters,
        scooter_groups: group_scooters_by_device_type(scooters),
        persian_today: Beroon.Calendar.persian_date(Reports.iran_today())
      )
    end
  end

  def manager_transports(conn, params) do
    branch = Operations.get_branch_for_manager_phone(conn.assigns.current_user_phone)

    if is_nil(branch) do
      redirect(conn, to: ~p"/manager/pending")
    else
      after_evening = params["after_evening"] == "1"
      bahonar = Operations.get_bahonar_branch()

      render(conn, :manager_transports,
        branch: branch,
        after_evening: after_evening,
        branches: Operations.list_active_transport_branches(),
        default_destination_id: bahonar && bahonar.id,
        transports: Logistics.list_transports_for_branch(branch.id),
        persian_today: Beroon.Calendar.persian_date(Reports.iran_today())
      )
    end
  end

  def create_manager_transport(conn, %{"transport" => params}) do
    branch = Operations.get_branch_for_manager_phone(conn.assigns.current_user_phone)
    code = params |> Map.get("code", "") |> String.trim()
    destination_id = params["destination_branch_id"]
    notes = params["notes"] || ""

    cond do
      is_nil(branch) ->
        redirect(conn, to: ~p"/manager/pending")

      code == "" ->
        conn
        |> put_flash(:error, "پلاک یا بارکد دستگاه را وارد کنید.")
        |> redirect(to: ~p"/manager/transports")

      true ->
        scooter = Fleet.get_scooter_by_plate_or_barcode_with_details(branch.id, code)
        destination = destination_id && Operations.get_branch(destination_id)

        cond do
          is_nil(scooter) ->
            conn
            |> put_flash(:error, "این دستگاه متعلق به شعبه شما نیست یا پیدا نشد.")
            |> redirect(to: ~p"/manager/transports")

          is_nil(destination) ->
            conn
            |> put_flash(:error, "شعبه مقصد معتبر نیست.")
            |> redirect(to: ~p"/manager/transports")

          true ->
            actor = %{phone: conn.assigns.current_user_phone, name: manager_name(branch)}

            case Logistics.register_transport(scooter, destination, branch, actor, notes) do
              {:ok, _transport} ->
                conn
                |> put_flash(:info, "حمل‌ونقل دستگاه #{scooter.plate} به شعبه #{destination.name} ثبت شد.")
                |> redirect(to: ~p"/manager/transports")

              {:error, :same_branch} ->
                conn
                |> put_flash(:error, "دستگاه همین حالا در شعبه مقصد قرار دارد.")
                |> redirect(to: ~p"/manager/transports")

              {:error, :not_owned_by_manager_branch} ->
                conn
                |> put_flash(:error, "این دستگاه متعلق به شعبه شما نیست.")
                |> redirect(to: ~p"/manager/transports")

              {:error, _reason} ->
                conn
                |> put_flash(:error, "ثبت حمل‌ونقل انجام نشد.")
                |> redirect(to: ~p"/manager/transports")
            end
        end
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
        persian_today: Beroon.Calendar.persian_date(Reports.iran_today())
      )
    end
  end

  def send_scooter_to_workshop(conn, %{"id" => id, "repair" => repair_params}) do
    notes = Map.get(repair_params, "notes", "")
    delivery_method = Map.get(repair_params, "delivery_method", "attendant")
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
        {:ok, _scooter} =
          send_scooter_to_workshop_with_report(scooter, branch, notes, delivery_method, conn)

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
        persian_today: Beroon.Calendar.persian_date(Reports.iran_today())
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
          persian_today: Beroon.Calendar.persian_date(Reports.iran_today())
        )

      is_nil(scooter) ->
        conn
        |> put_flash(:error, "دستگاهی با این پلاک در شعبه شما پیدا نشد.")
        |> render(:manager_repair_receive,
          branch: branch,
          plate: plate,
          persian_today: Beroon.Calendar.persian_date(Reports.iran_today())
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
          persian_today: Beroon.Calendar.persian_date(Reports.iran_today())
        )
    end
  end

  def manager_morning(conn, params) do
    branch = Operations.get_branch_for_manager_phone(conn.assigns.current_user_phone)
    code = params |> Map.get("code", "") |> String.trim()
    selected_scooter = selected_morning_scooter(branch, code)
    selected_transport = selected_scooter && branch && selected_scooter.branch_id != branch.id && selected_scooter.current_branch_id == branch.id
    selected_foreign = selected_scooter && branch && selected_scooter.branch_id != branch.id && !selected_transport

    if is_nil(branch) do
      redirect(conn, to: ~p"/manager/pending")
    else
      render(conn, :manager_morning,
        branch: branch,
        manager_name: manager_name(branch),
        checklist_items: Checklists.list_active_checklist_items(),
        selected_code: code,
        selected_scooter: selected_scooter,
        selected_transport: selected_transport,
        selected_foreign: selected_foreign,
        selected_submitted:
          selected_scooter && !selected_transport && !selected_foreign &&
            Reports.morning_scooter_submitted_today?(
              branch.id,
              selected_scooter.id
            ),
        persian_today: Beroon.Calendar.persian_date(Reports.iran_today())
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

  def workshop_info(conn, _params) do
    workshop = Operations.get_workshop_for_manager_phone(conn.assigns.current_user_phone)

    if is_nil(workshop) do
      conn
      |> put_flash(:error, "دسترسی تعمیرگاه برای این شماره فعال نیست.")
      |> redirect(to: ~p"/manager/pending")
    else
      render(conn, :workshop_info,
        workshop: workshop,
        branch_repairs: Reports.repair_report_counts_by_branch()
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
        scanned = Fleet.get_scooter_by_plate_or_barcode_with_details(params["code"] || "")
        message = if scanned && scanned.current_branch_id == branch.id && scanned.branch_id != branch.id, do: "این دستگاه برای حمل‌ونقل در شعبه شماست و در چک‌لیست صبح ثبت نمی‌شود.", else: "این دستگاه در شعبه شما پیدا نشد."
        conn
        |> put_flash(:error, message)
        |> redirect(to: ~p"/manager/morning")

      Reports.morning_scooter_submitted_today?(branch.id, scooter.id) ->
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
        "checked_on" => Reports.iran_today(),
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
        submitted: Reports.evening_submission_locked?(branch.id),
        persian_today: Beroon.Calendar.persian_date(Reports.iran_today())
      )
    end
  end

  def submit_evening(conn, %{"evening" => params}) do
    branch = Operations.get_branch_for_manager_phone(conn.assigns.current_user_phone)

    cond do
      is_nil(branch) ->
        redirect(conn, to: ~p"/manager/pending")

      Reports.evening_submission_locked?(branch.id) ->
        conn
        |> put_flash(:error, "آمار شب این شعبه قبلا ثبت شده و فعلا غیرفعال است.")
        |> redirect(to: ~p"/manager/evening")

      true ->
        do_submit_evening(conn, params, branch)
    end
  end

  defp do_submit_evening(conn, params, branch) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    scanned_codes =
      params |> Map.get("scanned_codes", []) |> List.wrap() |> Enum.reject(&(&1 == ""))

    scanned_scooters =
      Enum.map(scanned_codes, &Fleet.get_scooter_by_plate_or_barcode/1) |> Enum.reject(&is_nil/1)

    expected_scooters = Fleet.expected_evening_scooters_for_branch(branch.id)

    total_count =
      scanned_scooters
      |> Enum.uniq_by(& &1.id)
      |> Enum.count(&(&1.branch_id == branch.id))

    attrs =
      params
      |> Map.take(["notes"])
      |> Map.merge(%{
        "branch_id" => branch.id,
        "manager_name" => manager_name(branch),
        "manager_phone" => conn.assigns.current_user_phone,
        "total_count" => total_count,
        "available_count" => total_count,
        "rented_count" => 0,
        "damaged_count" => 0,
        "missing_count" => max(length(expected_scooters) - total_count, 0),
        "expected_scooter_ids" => Enum.map(expected_scooters, & &1.id),
        "counted_on" => Reports.evening_report_date(now),
        "counted_at" => now
      })

    case Reports.create_evening_count_with_items(attrs, scanned_scooters) do
      {:ok, _count} ->
        conn
        |> put_flash(:info, "آمار شب با مجموع #{total_count} دستگاه ثبت شد. آیا دستگاهی را برای حمل‌ونقل می‌برید؟")
        |> redirect(to: ~p"/manager/transports?after_evening=1")

      {:error, changeset} ->
        conn
        |> put_flash(:error, "آمار ثبت نشد: #{first_error(changeset)}")
        |> redirect(to: ~p"/manager/evening")
    end
  end

  def admin_device_locations(conn, params) do
    query = params |> Map.get("q", "") |> String.trim()

    render(conn, :admin_device_locations,
      query: query,
      result: Logistics.find_scooter_location(query),
      recent_transports: Logistics.list_recent_transports()
    )
  end

  def admin_reports(conn, _params) do
    date = Reports.iran_today()
    branches = Operations.list_branches()

    render(conn, :admin_reports,
      branches: branches,
      report_date: date,
      branch_report_statuses: Reports.branch_report_statuses(branches, date)
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
    date = Reports.iran_today()
    branches = Operations.list_branches()

    render(conn, :admin_evening_report_branches,
      branches: branches,
      report_date: date,
      branch_report_statuses: Reports.branch_report_statuses(branches, date)
    )
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

  def admin_report_export(conn, params) do
    date = parse_date(params["date"])

    render(conn, :admin_report_export,
      selected_date: date,
      persian_date: Beroon.Calendar.persian_date(date)
    )
  end

  def admin_new_device_inventory(conn, _params) do
    render(conn, :admin_new_device_inventory, stocks: Inventory.list_stocks())
  end

  def admin_new_device_sales(conn, _params) do
    render(conn, :admin_new_device_sales,
      stocks: Inventory.list_stocks(),
      sales: Inventory.list_sales()
    )
  end

  def update_new_device_stock(conn, %{"stock" => params}) do
    quantity = case Integer.parse(params["quantity"] || "0") do {n, _} -> n; _ -> -1 end
    case Inventory.set_stock(params["device_type_id"], quantity) do
      {:ok, _} -> conn |> put_flash(:info, "موجودی انبار نو به‌روزرسانی شد.") |> redirect(to: ~p"/admin/new-device-inventory")
      {:error, _} -> conn |> put_flash(:error, "موجودی نامعتبر است.") |> redirect(to: ~p"/admin/new-device-inventory")
    end
  end

  def create_new_device_sale(conn, %{"sale" => params}) do
    attrs = Map.merge(params, %{"sold_at" => DateTime.utc_now() |> DateTime.truncate(:second), "sold_by_phone" => conn.assigns.current_user_phone})
    case Inventory.create_sale(attrs) do
      {:ok, _} -> conn |> put_flash(:info, "فروش ثبت و از موجودی انبار نو کم شد.") |> redirect(to: ~p"/admin/new-device-sales")
      {:error, :stock, :insufficient_stock, _} -> conn |> put_flash(:error, "موجودی این نوع دستگاه کافی نیست.") |> redirect(to: ~p"/admin/new-device-sales")
      {:error, _, _, _} -> conn |> put_flash(:error, "ثبت فروش انجام نشد؛ ورودی‌ها را بررسی کنید.") |> redirect(to: ~p"/admin/new-device-sales")
    end
  end

  def admin_notifications(conn, _params) do
    render(conn, :admin_notifications,
      branches: Operations.list_active_branches(),
      subject: "",
      body: "",
      selected_branch_ids: []
    )
  end

  def send_admin_notification(conn, %{"notification" => params}) do
    branch_ids = params |> Map.get("branch_ids", []) |> List.wrap() |> Enum.reject(&(&1 == ""))
    subject = params |> Map.get("subject", "") |> String.trim()
    body = params |> Map.get("body", "") |> String.trim()

    cond do
      subject == "" or body == "" ->
        render_admin_notification_error(conn, params, "موضوع و متن پیام اجباری است.")

      branch_ids == [] ->
        render_admin_notification_error(conn, params, "حداقل یک شعبه را انتخاب کنید.")

      true ->
        {:ok, _notification} =
          Reports.create_branch_notification(
            %{
              "subject" => subject,
              "body" => body,
              "sent_by_admin_phone" => conn.assigns.current_user_phone
            },
            branch_ids
          )

        conn
        |> put_flash(:info, "پیام برای شعبه‌های انتخاب‌شده ارسال شد.")
        |> redirect(to: ~p"/admin/notifications")
    end
  end

  def download_admin_report_export(conn, params) do
    date = parse_date(params["date"])
    export = Reports.evening_inventory_export(date)
    filename = "beroon-evening-inventory-#{String.replace(Beroon.Calendar.persian_numeric_date(date), "/", "-")}.xls"

    conn
    |> put_resp_content_type("application/vnd.ms-excel; charset=utf-8")
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
    |> send_resp(200, evening_inventory_xls(export))
  end

  def admin_checklist_branches(conn, _params) do
    render(conn, :admin_checklist_branches,
      branches: Operations.list_branches(),
      date: Reports.iran_today()
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

  defp selected_morning_scooter(_branch, code) do
    Fleet.get_scooter_by_plate_or_barcode_with_details(code)
  end

  defp render_admin_notification_error(conn, params, message) do
    conn
    |> put_flash(:error, message)
    |> render(:admin_notifications,
      branches: Operations.list_active_branches(),
      subject: params |> Map.get("subject", "") |> String.trim(),
      body: params |> Map.get("body", "") |> String.trim(),
      selected_branch_ids: params |> Map.get("branch_ids", []) |> List.wrap()
    )
  end

  defp evening_inventory_xls(export) do
    header_cells =
      [
        "<th>نوع دستگاه</th>",
        Enum.map(export.branches, fn branch -> "<th>#{escape_html(branch.name)}</th>" end),
        "<th>داخل تعمیرگاه (پذیرش‌شده + در حال تعمیر)</th>",
        "<th>در انتظار قطعه</th>",
        "<th>انبار دستگاه‌های نو</th>",
        "<th>فروش‌رفته</th>",
        "<th>جمع ردیف</th>"
      ]

    body_rows =
      Enum.map(export.rows, fn row ->
        branch_values =
          Enum.map(export.branches, fn branch ->
            Map.get(row.branch_counts, branch.id, 0)
          end)

        row_total =
          Enum.sum(branch_values) + row.workshop_count + row.waiting_for_part_count +
            row.new_stock_count + row.sold_count

        branch_cells = Enum.map(branch_values, &"<td>#{&1}</td>")

        [
          "<tr>",
          "<td>#{escape_html(row.device_type.label)}</td>",
          branch_cells,
          "<td>#{row.workshop_count}</td>",
          "<td>#{row.waiting_for_part_count}</td>",
          "<td>#{row.new_stock_count}</td>",
          "<td>#{row.sold_count}</td>",
          "<td><strong>#{row_total}</strong></td>",
          "</tr>"
        ]
      end)

    total_branch_cells =
      Enum.map(export.branches, fn branch ->
        "<td><strong>#{Map.get(export.totals.branch_counts, branch.id, 0)}</strong></td>"
      end)

    total_row = [
      ~s(<tr class="total-row">),
      "<td><strong>جمع هر ستون</strong></td>",
      total_branch_cells,
      "<td><strong>#{export.totals.workshop_count}</strong></td>",
      "<td><strong>#{export.totals.waiting_for_part_count}</strong></td>",
      "<td><strong>#{export.totals.new_stock_count}</strong></td>",
      "<td><strong>#{export.totals.sold_count}</strong></td>",
      "<td><strong>#{export.grand_total}</strong></td>",
      "</tr>"
    ]

    column_count = length(export.branches) + 7

    [
      "\uFEFF",
      """
      <html>
        <head>
          <meta charset="UTF-8" />
          <style>
            body { font-family: Tahoma, Arial, sans-serif; direction: rtl; }
            table { border-collapse: collapse; direction: rtl; }
            th, td { border: 1px solid #999; padding: 8px 12px; text-align: center; }
            th { background: #ccf1ee; font-weight: bold; }
            td:first-child, th:first-child { text-align: right; min-width: 210px; }
            .total-row td { background: #e9f7f5; border-top: 3px solid #287f78; }
            .grand-total td { background: #fff4cc; font-size: 15px; border-top: 2px solid #a77b00; }
          </style>
        </head>
        <body>
          <h3>خروجی گزارش آمار شبانه - #{escape_html(Beroon.Calendar.persian_date(export.date))}</h3>
          <table>
            <thead>
              <tr>#{IO.iodata_to_binary(header_cells)}</tr>
            </thead>
            <tbody>
              #{IO.iodata_to_binary(body_rows)}
              #{IO.iodata_to_binary(total_row)}
              <tr class="grand-total">
                <td colspan="#{column_count}"><strong>جمع کل همه دستگاه‌ها: #{export.grand_total}</strong></td>
              </tr>
            </tbody>
          </table>
        </body>
      </html>
      """
    ]
    |> IO.iodata_to_binary()
  end

  defp escape_html(value) do
    value
    |> to_string()
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end

  defp parse_date(nil), do: Reports.iran_today()
  defp parse_date(""), do: Reports.iran_today()

  defp parse_date(date) do
    case Beroon.Calendar.parse_persian_date(date) do
      {:ok, parsed} -> parsed
      _ -> case Date.from_iso8601(date) do {:ok, parsed} -> parsed; _ -> Reports.iran_today() end
    end
  end

  defp parse_optional_date(nil), do: nil
  defp parse_optional_date(""), do: nil

  defp parse_optional_date(date) do
    case Beroon.Calendar.parse_persian_date(date) do
      {:ok, parsed} -> parsed
      _ -> case Date.from_iso8601(date) do {:ok, parsed} -> parsed; _ -> nil end
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


  defp group_scooters_by_device_type(scooters) do
    scooters
    |> Enum.group_by(fn scooter ->
      case scooter.device_type do
        nil -> {nil, "بدون نوع دستگاه"}
        device_type -> {device_type.id, BeroonWeb.PageHTML.device_type_label(device_type)}
      end
    end)
    |> Enum.map(fn {{_device_type_id, label}, grouped_scooters} ->
      %{label: label, scooters: Enum.sort_by(grouped_scooters, &String.downcase(&1.plate || ""))}
    end)
    |> Enum.sort_by(fn group -> String.downcase(group.label) end)
  end

  defp manager_scooters_for_status(branch_id, "workshop"),
    do: Fleet.list_scooters_for_branch_by_statuses(branch_id, @manager_workshop_statuses)

  defp manager_scooters_for_status(branch_id, status),
    do: Fleet.list_scooters_for_branch_with_details(branch_id, status)

  defp send_scooter_to_workshop_with_report(scooter, branch, notes, delivery_method, conn) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.transaction(fn ->
      updated_scooter =
        case Fleet.update_scooter(scooter, %{status: "needs_service", notes: notes}) do
          {:ok, scooter} -> scooter
          {:error, changeset} -> Repo.rollback(changeset)
        end

      case Reports.create_scooter_repair_report(%{
             scooter_id: scooter.id,
             branch_id: branch.id,
             reported_by_manager_name: manager_name(branch),
             reported_by_manager_phone: conn.assigns.current_user_phone,
             notes: notes,
             delivery_method: delivery_method,
             reported_on: Reports.iran_today(),
             reported_at: now
           }) do
        {:ok, _report} -> updated_scooter
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
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
