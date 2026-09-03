defmodule BeroonWeb.PageController do
  use BeroonWeb, :controller

  alias Beroon.Checklists
  alias Beroon.Catalog
  alias Beroon.Fleet
  alias Beroon.Logistics
  alias Beroon.Inventory
  alias Beroon.Operations
  alias Beroon.Repo
  alias Beroon.Reports
  alias Beroon.Thefts

  @manager_workshop_statuses ["awaiting_repair", "repairing"]
  @repair_technicians ["محب صافی", "احسان طیاری", "میثاق پرتو"]

  def catalog(conn, params) do
    conn
    |> put_root_layout(false)
    |> put_layout(false)
    |> render(:catalog, lead_error: params["lead_error"] == "1")
  end

  def create_catalog_lead(conn, %{"lead" => params}) do
    case Catalog.create_lead(params) do
      {:ok, _lead} -> redirect(conn, to: ~p"/catalog?unlocked=1")
      {:error, _changeset} -> redirect(conn, to: ~p"/catalog?lead_error=1")
    end
  end

  def admin_catalog_leads(conn, _params) do
    render(conn, :admin_catalog_leads, leads: Catalog.list_leads())
  end

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
        scooter_counts: manager_scooter_counts(branch.id),
        persian_today: Beroon.Calendar.persian_date(today),
        morning_submitted:
          Reports.morning_submitted_today?(branch.id, today),
        evening_submitted:
          Reports.evening_submitted_for_cycle?(branch.id)
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
        morning_submitted: Reports.morning_submitted_today?(branch.id, today),
        evening_submitted: Reports.evening_submitted_for_cycle?(branch.id)
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

  def manager_unhealthy_scooters(conn, _params) do
    branch = Operations.get_branch_for_manager_phone(conn.assigns.current_user_phone)

    if is_nil(branch) do
      redirect(conn, to: ~p"/manager/pending")
    else
      date = Reports.iran_today()

      render(conn, :manager_unhealthy_scooters,
        branch: branch,
        date: date,
        scooters: Reports.list_unhealthy_scooters_for_branch(date, branch.id)
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
        scooters: Fleet.list_repair_candidates(branch.id, query),
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
    scooter = branch && Fleet.get_scooter_with_details!(id)

    cond do
      is_nil(branch) ->
        redirect(conn, to: ~p"/manager/pending")

      is_nil(scooter) ->
        conn
        |> put_flash(:error, "دستگاه پیدا نشد.")
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
        {:ok, _scooter} =
          Fleet.update_scooter(scooter, %{
            status: "active",
            notes: nil,
            current_branch_id: branch.id
          })

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
        scanned_scooters: Reports.list_morning_scanned_scooters(branch.id, Reports.iran_today()),
        unscanned_scooters: Reports.list_unchecked_scooters_for_branch(Reports.iran_today(), branch.id),
        persian_today: Beroon.Calendar.persian_date(Reports.iran_today())
      )
    end
  end

  def workshop_home(conn, params) do
    workshop = Operations.get_workshop_for_manager_phone(conn.assigns.current_user_phone)
    query = params |> Map.get("q", "") |> String.trim()

    if is_nil(workshop) do
      conn |> put_flash(:error, "دسترسی تعمیرگاه برای این شماره فعال نیست.") |> redirect(to: ~p"/manager/pending")
    else
      selected = if query == "", do: nil, else: Fleet.get_scooter_by_plate_or_barcode_with_details(query)
      render(conn, :workshop_home,
        workshop: workshop, query: query, selected_scooter: selected,
        acceptance: Fleet.list_scooters_by_statuses(["needs_service"]),
        repairing: Fleet.list_scooters_by_statuses(["awaiting_repair", "repairing"]),
        waiting_part: Fleet.list_scooters_by_statuses(["waiting_for_part"]),
        ready: Fleet.list_scooters_by_statuses(["ready_for_pickup"]),
        repair_technicians: @repair_technicians
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
         {:ok, _scooter} <-
           Fleet.update_scooter(scooter, %{
             status: "awaiting_repair",
             current_branch_id: workshop.id
           }) do
      record_workshop_event(scooter.id, "accepted", conn.assigns.current_user_phone)
      conn
      |> put_flash(:info, "پذیرش دستگاه در #{workshop.name} ثبت شد.")
      |> redirect(to: ~p"/workshop?q=#{scooter.plate}")
    else
      _ ->
        conn
        |> put_flash(:error, "پذیرش دستگاه انجام نشد.")
        |> redirect(to: ~p"/workshop/acceptance")
    end
  end

  def workshop_start_repair(conn, %{"id" => id} = params) do
    workshop = Operations.get_workshop_for_manager_phone(conn.assigns.current_user_phone)
    scooter = Fleet.get_scooter!(id)
    attrs = %{status: "repairing"} |> then(fn a -> if workshop, do: Map.put(a, :current_branch_id, workshop.id), else: a end)
    case Fleet.update_scooter(scooter, attrs) do
      {:ok, _} ->
        technician = params |> get_in(["repair", "technician_name"]) |> to_string() |> String.trim()
        extra = if technician in @repair_technicians, do: %{technician_name: technician}, else: %{}
        record_workshop_event(scooter.id, "repair_started", conn.assigns.current_user_phone, extra)
        conn |> put_flash(:info, "دستگاه وارد مرحله تعمیر شد.") |> redirect(to: ~p"/workshop?q=#{scooter.plate}")
      {:error, _} -> conn |> put_flash(:error, "تغییر وضعیت دستگاه انجام نشد.") |> redirect(to: ~p"/workshop/repairing")
    end
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
      ~p"/workshop"
    )
  end

  def workshop_update_notes(conn, %{"id" => id} = params) do
    scooter = Fleet.get_scooter!(id)
    notes = params |> get_in(["repair", "notes"]) |> to_string() |> String.trim()

    if scooter.status in ["repairing", "waiting_for_part", "awaiting_repair"] do
      case Fleet.update_scooter(scooter, %{notes: notes}) do
        {:ok, _} ->
          conn
          |> put_flash(:info, "توضیحات دستگاه ذخیره شد.")
          |> redirect(to: ~p"/workshop?q=#{scooter.plate}")

        {:error, _} ->
          conn
          |> put_flash(:error, "ذخیره توضیحات انجام نشد.")
          |> redirect(to: ~p"/workshop?q=#{scooter.plate}")
      end
    else
      conn
      |> put_flash(:error, "در وضعیت فعلی امکان ویرایش توضیحات تعمیر وجود ندارد.")
      |> redirect(to: ~p"/workshop?q=#{scooter.plate}")
    end
  end


  def workshop_discharge_scooter(conn, %{"id" => id, "discharge" => params}) do
    parts_used = params |> Map.get("repair_parts_used", "") |> String.trim()
    technician = params |> Map.get("technician_name", "") |> String.trim()
    scooter = Fleet.get_scooter!(id)

    cond do
      parts_used == "" ->
        conn |> put_flash(:error, "ثبت قطعات مصرف‌شده برای ترخیص الزامی است.") |> redirect(to: ~p"/workshop/discharge")

      technician not in @repair_technicians ->
        conn |> put_flash(:error, "انتخاب تعمیرکار برای ترخیص الزامی است.") |> redirect(to: ~p"/workshop/discharge")

      true ->
        workshop = Operations.get_workshop_for_manager_phone(conn.assigns.current_user_phone)
        attrs =
          %{status: "ready_for_pickup", repair_parts_used: parts_used, repair_technician: technician}
          |> then(fn a -> if workshop, do: Map.put(a, :current_branch_id, workshop.id), else: a end)

        case Fleet.update_scooter(scooter, attrs) do
          {:ok, _} ->
            record_workshop_event(
              scooter.id,
              "discharged",
              conn.assigns.current_user_phone,
              %{technician_name: technician, repair_parts_used: parts_used}
            )

            conn |> put_flash(:info, "دستگاه آماده تحویل شد.") |> redirect(to: ~p"/workshop?q=#{scooter.plate}")

          {:error, _} ->
            conn |> put_flash(:error, "ترخیص دستگاه انجام نشد.") |> redirect(to: ~p"/workshop/discharge")
        end
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
        scanned = Fleet.get_scooter_by_plate_or_barcode_with_details(params["code"] || "")
        message = if scanned && scanned.current_branch_id == branch.id && scanned.branch_id != branch.id, do: "این دستگاه برای حمل‌ونقل در شعبه شماست و در چک‌لیست صبح ثبت نمی‌شود.", else: "این دستگاه در شعبه شما پیدا نشد."
        conn
        |> put_flash(:error, message)
        |> redirect(to: ~p"/manager/morning")

      scooter.status == "stolen" ->
        conn
        |> put_flash(:error, "این دستگاه به‌عنوان سرقتی ثبت شده و در چک‌لیست صبح محاسبه نمی‌شود.")
        |> redirect(to: ~p"/manager/morning")

      scooter.status == "loaned" ->
        conn
        |> put_flash(:error, "این دستگاه امانی است و در چک‌لیست صبح محاسبه نمی‌شود.")
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
    scooter = Logistics.activate_owner_return(scooter, branch.id)
    scooter = Logistics.mark_seen_at_branch(scooter, branch.id)
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
        submitted: Reports.evening_submitted_for_cycle?(branch.id),
        window_open: Reports.evening_window_open?(),
        daily_revenue: Reports.get_daily_revenue(branch.id, Reports.evening_report_date(DateTime.utc_now())),
        persian_today: Beroon.Calendar.persian_date(Reports.iran_today())
      )
    end
  end

  def submit_evening(conn, %{"evening" => params}) do
    branch = Operations.get_branch_for_manager_phone(conn.assigns.current_user_phone)

    cond do
      is_nil(branch) ->
        redirect(conn, to: ~p"/manager/pending")

      not Reports.evening_window_open?() ->
        conn
        |> put_flash(:error, "آمارگیری شب فقط از ساعت ۲۱:۰۰ تا ۰۶:۰۰ صبح فعال است.")
        |> redirect(to: ~p"/manager/evening")

      Reports.evening_submitted_for_cycle?(branch.id) ->
        conn
        |> put_flash(:error, "آمار شب این شعبه برای این بازه قبلا ثبت شده است.")
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
      scanned_codes
      |> Enum.map(&Fleet.get_scooter_by_plate_or_barcode/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.reject(fn scooter -> scooter.status in ["loaned", "stolen"] end)
      |> Enum.map(&Logistics.mark_evening_seen(&1, branch.id))
      |> Enum.uniq_by(& &1.id)

    expected_scooters = Fleet.expected_evening_scooters_for_branch(branch.id)
    expected_ids = Enum.map(expected_scooters, & &1.id)
    scanned_ids = Enum.map(scanned_scooters, & &1.id)

    total_count = length(scanned_scooters)
    missing_count = Enum.count(expected_ids -- scanned_ids)

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
        "missing_count" => missing_count,
        "expected_scooter_ids" => Enum.map(expected_scooters, & &1.id),
        "counted_on" => Reports.evening_report_date(now),
        "counted_at" => now
      })

    case Reports.create_evening_count_with_items(attrs, scanned_scooters) do
      {:ok, _count} ->
        record_evening_revenue(branch, conn.assigns.current_user_phone, attrs["counted_on"], params)

        conn
        |> put_flash(:info, "آمار شب با مجموع #{total_count} دستگاه ثبت شد.")
        |> redirect(to: ~p"/manager/evening")

      {:error, changeset} ->
        conn
        |> put_flash(:error, "آمار ثبت نشد: #{first_error(changeset)}")
        |> redirect(to: ~p"/manager/evening")
    end
  end

  defp record_evening_revenue(branch, manager_phone, reported_on, params) do
    Reports.upsert_daily_revenue(%{
      branch_id: branch.id,
      reported_on: reported_on,
      cash_amount: parse_money(params["cash_amount"]),
      card_to_card_amount: parse_money(params["card_to_card_amount"]),
      registered_by_phone: manager_phone
    })
  end

  def manager_dinner(conn, _params) do
    branch = Operations.get_branch_for_manager_phone(conn.assigns.current_user_phone)
    today = Reports.iran_today()

    if is_nil(branch) do
      redirect(conn, to: ~p"/manager/pending")
    else
      render(conn, :manager_dinner,
        branch: branch,
        persian_today: Beroon.Calendar.persian_date(today),
        dinner_report: Reports.get_dinner_report(branch.id, today)
      )
    end
  end

  def submit_dinner(conn, %{"dinner" => params}) do
    branch = Operations.get_branch_for_manager_phone(conn.assigns.current_user_phone)
    today = Reports.iran_today()

    names =
      params
      |> Map.get("attendant_names", [])
      |> List.wrap()
      |> Enum.map(&String.trim(to_string(&1 || "")))
      |> Enum.reject(&(&1 == ""))

    if is_nil(branch) do
      redirect(conn, to: ~p"/manager/pending")
    else
      case Reports.upsert_dinner_report(%{
             branch_id: branch.id,
             reported_on: today,
             attendant_count: length(names),
             attendant_names: names,
             registered_by_phone: conn.assigns.current_user_phone
           }) do
        {:ok, _report} ->
          conn
          |> put_flash(:info, "آمار شام با #{length(names)} نفر ثبت شد.")
          |> redirect(to: ~p"/manager/dinner")

        {:error, changeset} ->
          conn
          |> put_flash(:error, "ثبت آمار شام انجام نشد: #{first_error(changeset)}")
          |> redirect(to: ~p"/manager/dinner")
      end
    end
  end

  def admin_dinner(conn, params) do
    date = parse_optional_date(params["date"]) || Reports.iran_today()

    render(conn, :admin_dinner,
      selected_date: date,
      dinner_reports: Reports.list_dinner_reports_for_date(date)
    )
  end

  def admin_stale_unscanned_scooters(conn, _params) do
    render(conn, :admin_stale_unscanned_scooters,
      scooters: Reports.list_scooters_not_scanned_since(48)
    )
  end

  def bulk_delete_stale_unscanned_scooters(conn, params) do
    scooter_ids = List.wrap(params["scooter_ids"])
    confirmation = params["confirmation"] |> to_string() |> String.trim()

    cond do
      scooter_ids == [] ->
        conn
        |> put_flash(:error, "حداقل یک دستگاه را انتخاب کنید.")
        |> redirect(to: ~p"/admin/unscanned-devices")

      confirmation != "حذف کامل" ->
        conn
        |> put_flash(:error, "برای تأیید حذف، عبارت «حذف کامل» را دقیق وارد کنید.")
        |> redirect(to: ~p"/admin/unscanned-devices")

      true ->
        case Fleet.permanently_delete_scooters(scooter_ids) do
          {:ok, %{scooters: {deleted_count, _}}} ->
            conn
            |> put_flash(:info, "#{deleted_count} دستگاه و تمام سوابق وابسته آن‌ها برای همیشه حذف شد.")
            |> redirect(to: ~p"/admin/unscanned-devices")

          {:error, _step, reason, _changes} ->
            conn
            |> put_flash(:error, "حذف کامل انجام نشد: #{inspect(reason)}")
            |> redirect(to: ~p"/admin/unscanned-devices")

          {:error, :no_scooters_selected} ->
            conn
            |> put_flash(:error, "هیچ دستگاه معتبری برای حذف انتخاب نشد.")
            |> redirect(to: ~p"/admin/unscanned-devices")
        end
    end
  end

  def admin_device_locations(conn, params) do
    query = params |> Map.get("q", "") |> String.trim()

    result = Logistics.find_scooter_location(query)

    render(conn, :admin_device_locations,
      query: query,
      result: result,
      location_history:
        if(result, do: Beroon.LocationHistory.list_recent(result.scooter.id, 10), else: [])
    )
  end

  def admin_device_detail(conn, %{"plate" => plate}) do
    case Fleet.get_scooter_by_plate_or_barcode_with_details(plate) do
      nil ->
        conn
        |> put_flash(:error, "دستگاهی با این پلاک پیدا نشد.")
        |> redirect(to: ~p"/admin/device-locations")

      scooter ->
        render(conn, :admin_device_detail,
          scooter: scooter,
          location_history: Beroon.LocationHistory.list_recent(scooter.id, 10)
        )
    end
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
    branches = Operations.list_active_transport_branches()

    render(conn, :admin_evening_report_branches,
      branches: branches,
      report_date: date,
      branch_report_statuses: Reports.branch_report_statuses(branches, date)
    )
  end

  def admin_branch_evening_reports(conn, %{"id" => id} = params) do
    branch = Operations.get_branch!(id)
    selected_date = parse_optional_date(params["date"]) || Reports.current_evening_cycle_date()
    audit = Reports.branch_evening_audit_for_date(branch.id, selected_date)

    render(conn, :admin_branch_evening_reports,
      branch: branch,
      selected_date: selected_date,
      audit: audit,
      audit_export_json: evening_audit_export_json(branch, selected_date, audit)
    )
  end

  defp evening_audit_export_json(branch, date, audit) do
    category = fn item ->
      %{
        plate: item.plate,
        barcode: item.barcode,
        device_type:
          [item[:device_type_identifier], item[:device_type_category], item[:device_type_name]]
          |> Enum.reject(&(&1 in [nil, ""]))
          |> Enum.join(" - "),
        reason: Map.get(item, :accounted_reason)
      }
    end

    build_category = fn key, title, color, list ->
      items = Enum.map(list, category)

      device_type_summary =
        items
        |> Enum.frequencies_by(fn item ->
          if item.device_type == "", do: "بدون نوع دستگاه", else: item.device_type
        end)
        |> Enum.map(fn {label, count} -> %{label: label, count: count} end)
        |> Enum.sort_by(& &1.label)

      %{key: key, title: title, color: color, items: items, device_type_summary: device_type_summary}
    end

    revenue = Reports.get_daily_revenue(branch.id, date)

    Jason.encode!(%{
      branch_name: branch.name,
      date_label: Beroon.Calendar.persian_numeric_date(date),
      submitted: audit.submitted,
      revenue: %{
        cash_amount: (revenue && revenue.cash_amount) || 0,
        card_to_card_amount: (revenue && revenue.card_to_card_amount) || 0
      },
      categories: [
        build_category.("scanned", "اسکن‌شده", "#059669", audit.scanned),
        build_category.("moved", "جابجا شده", "#0284c7", audit.moved),
        build_category.("workshop", "تعمیرگاه، امانی، سرقتی", "#7c3aed", audit.workshop),
        build_category.("needs_review", "نیاز به بررسی", "#dc2626", audit.needs_review)
      ]
    })
  end

  def admin_evening_report_detail(conn, %{"id" => id}) do
    report = Reports.get_evening_count_report!(id)
    branch = Operations.get_branch!(report.branch_id)

    render(conn, :admin_evening_report_detail,
      branch: branch,
      report: report
    )
  end

  def reopen_branch_evening_report(conn, %{"id" => id} = params) do
    branch = Operations.get_branch!(id)
    selected_date = parse_optional_date(params["date"]) || Reports.current_evening_cycle_date()

    case Reports.reopen_branch_evening_count(branch.id, selected_date) do
      {:ok, %{deleted_reports: 0}} ->
        conn
        |> put_flash(:error, "برای این شعبه در تاریخ انتخاب‌شده آمار نهایی ثبت نشده است.")
        |> redirect(to: ~p"/admin/evening-reports/branches/#{branch}?date=#{Beroon.Calendar.persian_numeric_date(selected_date)}")

      {:ok, %{deleted_reports: deleted_reports}} ->
        conn
        |> put_flash(:info, "آمار شب شعبه #{branch.name} حذف و مجدداً باز شد. مدیر شعبه اکنون می‌تواند آمار را از نو ثبت کند. (#{deleted_reports} رکورد حذف شد)")
        |> redirect(to: ~p"/admin/evening-reports/branches/#{branch}?date=#{Beroon.Calendar.persian_numeric_date(selected_date)}")

      {:error, reason} ->
        conn
        |> put_flash(:error, "بازکردن مجدد آمار انجام نشد: #{inspect(reason)}")
        |> redirect(to: ~p"/admin/evening-reports/branches/#{branch}?date=#{Beroon.Calendar.persian_numeric_date(selected_date)}")
    end
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

  def admin_sales_rack(conn, _params) do
    render(conn, :admin_sales_rack, stocks: Inventory.list_sales_rack_stocks())
  end

  def update_sales_rack_stock(conn, %{"stock" => params}) do
    quantity =
      case Integer.parse(params["quantity"] || "0") do
        {n, _} -> n
        _ -> -1
      end

    case Inventory.set_sales_rack_stock(params["device_type_id"], quantity) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "موجودی رگال فروش به‌روزرسانی شد.")
        |> redirect(to: ~p"/admin/sales-rack")

      {:error, _} ->
        conn
        |> put_flash(:error, "موجودی نامعتبر است.")
        |> redirect(to: ~p"/admin/sales-rack")
    end
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

  def admin_repair_stats(conn, params) do
    from_date = parse_date(params["from"])
    to_date = parse_date(params["to"] || params["from"])
    render(conn, :admin_repair_stats, from_date: from_date, to_date: to_date, rows: Reports.workshop_stats(from_date, to_date))
  end

  def download_admin_repair_stats(conn, params) do
    from_date = parse_date(params["from"])
    to_date = parse_date(params["to"] || params["from"])
    rows = Reports.workshop_stats(from_date, to_date)
    html = repair_stats_xls(rows)
    conn |> put_resp_content_type("application/vnd.ms-excel; charset=utf-8") |> put_resp_header("content-disposition", ~s(attachment; filename="repair-stats.xls")) |> send_resp(200, html)
  end

  def admin_loaned_scooters(conn, _params) do
    render(conn, :admin_loaned_scooters, loans: Logistics.list_open_loans())
  end

  def create_admin_scooter_loan(conn, %{"loan" => params}) do
    code = params |> Map.get("code", "") |> String.trim()
    unit = params |> Map.get("unit_name", "") |> String.trim()
    scooter = Fleet.get_scooter_by_plate_or_barcode_with_details(code)
    cond do
      is_nil(scooter) -> conn |> put_flash(:error, "دستگاه پیدا نشد.") |> redirect(to: ~p"/admin/loaned-scooters")
      unit == "" -> conn |> put_flash(:error, "نام واحد امانت‌گیرنده اجباری است.") |> redirect(to: ~p"/admin/loaned-scooters")
      scooter.status == "loaned" -> conn |> put_flash(:error, "این دستگاه قبلاً امانی شده است.") |> redirect(to: ~p"/admin/loaned-scooters")
      scooter.status == "stolen" -> conn |> put_flash(:error, "دستگاه سرقتی را نمی‌توان امانی ثبت کرد.") |> redirect(to: ~p"/admin/loaned-scooters")
      true ->
        case Logistics.loan_scooter(scooter, %{unit_name: unit, notes: params["notes"], registered_by_phone: conn.assigns.current_user_phone}) do
          {:ok, _} -> conn |> put_flash(:info, "دستگاه امانی ثبت شد.") |> redirect(to: ~p"/admin/loaned-scooters")
          {:error, _} -> conn |> put_flash(:error, "ثبت دستگاه امانی انجام نشد.") |> redirect(to: ~p"/admin/loaned-scooters")
        end
    end
  end

  def return_admin_scooter_loan(conn, %{"id" => id}) do
    loan = Repo.get!(Beroon.Logistics.ScooterLoan, id)
    case Logistics.return_loan(loan) do
      {:ok, _} -> conn |> put_flash(:info, "بازگشت دستگاه ثبت شد.") |> redirect(to: ~p"/admin/loaned-scooters")
      {:error, _} -> conn |> put_flash(:error, "ثبت بازگشت انجام نشد.") |> redirect(to: ~p"/admin/loaned-scooters")
    end
  end

  def admin_stolen_devices(conn, _params) do
    records = Thefts.list_open_stolen_devices()

    branch_totals =
      records
      |> Enum.group_by(& &1.branch.name)
      |> Enum.map(fn {branch_name, items} ->
        %{branch_name: branch_name, quantity: Enum.reduce(items, 0, &(&1.quantity + &2))}
      end)
      |> Enum.sort_by(& &1.branch_name)

    render(conn, :admin_stolen_devices,
      records: records,
      total_count: Enum.reduce(records, 0, &(&1.quantity + &2)),
      branch_totals: branch_totals,
      branches: Operations.list_active_transport_branches(),
      device_types: Fleet.list_device_types()
    )
  end

  def create_admin_stolen_device(conn, %{"theft" => params}) do
    mode = params |> Map.get("mode", "") |> String.trim()
    branch_id = params |> Map.get("branch_id", "") |> String.trim()
    notes = params |> Map.get("notes", "") |> String.trim()

    result =
      case mode do
        "plated" ->
          code = params |> Map.get("code", "") |> String.trim()
          scooter = Fleet.get_scooter_by_plate_or_barcode_with_details(code)

          cond do
            branch_id == "" -> {:error, :branch_required}
            code == "" -> {:error, :code_required}
            is_nil(scooter) -> {:error, :scooter_not_found}
            true ->
              Thefts.register_plated_scooter(scooter, branch_id, %{
                notes: notes,
                registered_by_phone: conn.assigns.current_user_phone
              })
          end

        "unplated" ->
          Thefts.register_unplated_devices(%{
            branch_id: branch_id,
            device_type_id: params["device_type_id"],
            quantity: params["quantity"],
            notes: notes,
            registered_by_phone: conn.assigns.current_user_phone
          })

        _ ->
          {:error, :invalid_mode}
      end

    case result do
      {:ok, _record} ->
        conn
        |> put_flash(:info, "آمار دستگاه سرقتی ثبت شد.")
        |> redirect(to: ~p"/admin/stolen-devices")

      {:error, :already_stolen} ->
        conn
        |> put_flash(:error, "این دستگاه قبلاً به‌عنوان سرقتی ثبت شده است.")
        |> redirect(to: ~p"/admin/stolen-devices")

      {:error, :scooter_not_found} ->
        conn
        |> put_flash(:error, "دستگاهی با این پلاک یا QR پیدا نشد.")
        |> redirect(to: ~p"/admin/stolen-devices")

      {:error, :code_required} ->
        conn
        |> put_flash(:error, "واردکردن پلاک یا QR دستگاه الزامی است.")
        |> redirect(to: ~p"/admin/stolen-devices")

      {:error, :branch_required} ->
        conn
        |> put_flash(:error, "انتخاب شعبه الزامی است.")
        |> redirect(to: ~p"/admin/stolen-devices")

      {:error, :device_type_missing} ->
        conn
        |> put_flash(:error, "نوع دستگاه برای این پلاک مشخص نشده است.")
        |> redirect(to: ~p"/admin/stolen-devices")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_flash(:error, "ثبت آمار سرقتی انجام نشد: #{first_error(changeset)}")
        |> redirect(to: ~p"/admin/stolen-devices")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "اطلاعات واردشده کامل یا معتبر نیست.")
        |> redirect(to: ~p"/admin/stolen-devices")
    end
  end

  def recover_admin_stolen_device(conn, %{"id" => id}) do
    record = Thefts.get_stolen_device!(id)

    case Thefts.recover(record) do
      {:ok, _record} ->
        conn
        |> put_flash(:info, "پیداشدن یا بازگشت دستگاه ثبت شد.")
        |> redirect(to: ~p"/admin/stolen-devices")

      {:error, _step, reason, _changes} ->
        conn
        |> put_flash(:error, "ثبت بازگشت انجام نشد: #{inspect(reason)}")
        |> redirect(to: ~p"/admin/stolen-devices")

      {:error, reason} ->
        conn
        |> put_flash(:error, "ثبت بازگشت انجام نشد: #{inspect(reason)}")
        |> redirect(to: ~p"/admin/stolen-devices")
    end
  end

  def download_admin_report_export(conn, params) do
    date = parse_date(params["date"])
    export = Reports.evening_inventory_export(date)
    filename = "beroon-evening-inventory-#{String.replace(Beroon.Calendar.persian_numeric_date(date), "/", "-")}.xlsx"

    conn
    |> put_resp_content_type("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
    |> send_resp(200, evening_inventory_xlsx(export))
  end

  def download_admin_reference_export(conn, _params) do
    export = Reports.reference_inventory_export()

    filename =
      "beroon-reference-inventory-#{String.replace(Beroon.Calendar.persian_numeric_date(export.date), "/", "-")}.xlsx"

    conn
    |> put_resp_content_type("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
    |> send_resp(200, reference_inventory_xlsx(export))
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

  defp reference_inventory_xlsx(export) do
    main_rows =
      inventory_sheet_rows(
        "آمار مرجع ناوگان",
        export.date,
        export.branches,
        export.rows,
        export.totals,
        :reference
      )

    loan_rows = loan_details_sheet_rows(export.loan_details)

    summary_rows =
      summary_sheet_rows("خلاصه مدیریتی آمار مرجع", export.date, [
        {"تعداد کل دستگاه‌های شعب", export.totals.branches_total_count},
        {"تعداد کل دستگاه‌های در انتظار قطعه", export.totals.waiting_for_part_count},
        {"تعداد کل دستگاه‌های امانی", export.totals.loaned_count},
        {"تعداد کل دستگاه‌های سرقتی", export.totals.stolen_count},
        {"تعداد کل دستگاه‌های انبار نو", export.totals.new_stock_count},
        {"تعداد کل دستگاه‌های رگال فروش", export.totals.sales_rack_count},
        {"جمع کل ناوگان", export.totals.grand_total_count}
      ])

    xlsx_workbook([
      {"آمار مرجع", main_rows},
      {"دستگاه‌های امانی", loan_rows},
      {"خلاصه مدیریتی", summary_rows}
    ])
  end

  defp evening_inventory_xlsx(export) do
    main_rows =
      inventory_sheet_rows(
        "گزارش روزانه ناوگان",
        export.date,
        export.branches,
        export.rows,
        export.totals,
        :daily
      )

    loan_rows = loan_details_sheet_rows(export.loan_details)

    summary_rows =
      summary_sheet_rows("خلاصه مدیریتی گزارش روزانه", export.date, [
        {"تعداد دستگاه‌های اسکن‌شده همه شعب", export.totals.branches_total_count},
        {"تعداد دستگاه‌های تعمیرگاه", export.totals.workshop_total_count},
        {"تعداد دستگاه‌های در انتظار قطعه", export.totals.waiting_for_part_count},
        {"تعداد دستگاه‌های امانی", export.totals.loaned_count},
        {"تعداد دستگاه‌های سرقتی", export.totals.stolen_count},
        {"موقعیت معلوم / جابه‌جایی ثبت‌شده", export.totals.location_known_count},
        {"جمع کل تعیین تکلیف شده‌ها", export.totals.accounted_total_count},
        {"نیاز به بررسی (خارج از جمع کل)", export.totals.needs_review_count},
        {"جمع کل ناوگان (بدون نیاز به بررسی، انبار نو و فروش)", export.totals.operational_total_count},
        {"موجودی انبار نو (جدا از ناوگان)", export.totals.new_stock_count},
        {"موجودی رگال فروش (جدا از ناوگان)", export.totals.sales_rack_count},
        {"جمع موجودی انبار نو و رگال فروش", export.totals.new_stock_count + export.totals.sales_rack_count},
        {"فروش ثبت‌شده (جدا از ناوگان)", export.totals.sold_count}
      ])

    workshop_rows = workshop_discharge_sheet_rows(export.date)
    revenue_rows = revenue_sheet_rows(export.date, export.revenue_details)

    xlsx_workbook([
      {"گزارش روزانه", main_rows},
      {"دستگاه‌های امانی", loan_rows},
      {"خلاصه مدیریتی", summary_rows},
      {"تعمیرگاه", workshop_rows},
      {"درآمد شعب", revenue_rows}
    ])
  end

  defp revenue_sheet_rows(date, revenue_details) do
    headers = ["ردیف", "شعبه", "کارت به کارت (تومان)", "نقدی (تومان)", "جمع (تومان)"]

    rows =
      revenue_details
      |> Enum.with_index(1)
      |> Enum.map(fn {revenue, index} ->
        [
          index,
          revenue.branch_name,
          revenue.card_to_card_amount,
          revenue.cash_amount,
          revenue.total_amount
        ]
      end)

    total_cash = Enum.reduce(revenue_details, 0, &(&1.cash_amount + &2))
    total_card = Enum.reduce(revenue_details, 0, &(&1.card_to_card_amount + &2))
    total_all = total_cash + total_card

    [
      [{"درآمد نقدی و کارت‌به‌کارت شعب", "Title"}],
      [{"تاریخ گزارش: #{Beroon.Calendar.persian_date(date)}", "Subtitle"}],
      [],
      Enum.map(headers, &{&1, "Header"})
    ] ++
      rows ++
      [
        [{"جمع کل", "Total"}, {"", "Total"}, {total_card, "Total"}, {total_cash, "Total"}, {total_all, "Total"}]
      ]
  end

  defp inventory_sheet_rows(title, date, branches, rows, totals, mode) do
    fixed_headers =
      case mode do
        :reference -> ["جمع شعب", "در انتظار قطعه", "انبار نو", "رگال فروش", "امانی", "سرقتی", "جمع کل"]
        :daily -> [
          "تعمیرگاه",
          "در انتظار قطعه",
          "امانی",
          "سرقتی",
          "موقعیت معلوم / جابه‌جایی",
          "جمع کل ناوگان",
          "انبار نو",
          "رگال فروش",
          "فروش",
          "جمع کل اسکن‌شده‌ها",
          "جمع کل تعیین تکلیف شده‌ها",
          "جمع کل نیاز به بررسی"
        ]
      end

    headers = ["نوع دستگاه"] ++ Enum.map(branches, & &1.name) ++ fixed_headers

    data_rows =
      Enum.map(rows, fn row ->
        branch_values = Enum.map(branches, &Map.get(row.branch_counts, &1.id, 0))

        fixed_values =
          case mode do
            :reference ->
              [
                row.branches_total_count,
                row.waiting_for_part_count,
                row.new_stock_count,
                row.sales_rack_count,
                row.loaned_count,
                row.stolen_count,
                row.grand_total_count
              ]

            :daily ->
              [
                row.workshop_total_count,
                row.waiting_for_part_count,
                row.loaned_count,
                row.stolen_count,
                row.location_known_count,
                row.operational_total_count,
                row.new_stock_count,
                row.sales_rack_count,
                row.sold_count,
                row.branches_total_count,
                row.accounted_total_count,
                row.needs_review_count
              ]
          end

        [row.device_type.label] ++ branch_values ++ fixed_values
      end)

    total_branch_values = Enum.map(branches, &Map.get(totals.branch_counts, &1.id, 0))

    total_fixed_values =
      case mode do
        :reference ->
          [
            totals.branches_total_count,
            totals.waiting_for_part_count,
            totals.new_stock_count,
            totals.sales_rack_count,
            totals.loaned_count,
            totals.stolen_count,
            totals.grand_total_count
          ]

        :daily ->
          [
            totals.workshop_total_count,
            totals.waiting_for_part_count,
            totals.loaned_count,
            totals.stolen_count,
            totals.location_known_count,
            totals.operational_total_count,
            totals.new_stock_count,
            totals.sales_rack_count,
            totals.sold_count,
            totals.branches_total_count,
            totals.accounted_total_count,
            totals.needs_review_count
          ]
      end

    [
      [{title, "Title"}],
      [{"تاریخ گزارش: #{Beroon.Calendar.persian_date(date)}", "Subtitle"}],
      [],
      Enum.map(headers, &{&1, "Header"})
    ] ++
      data_rows ++
      [[{"جمع همه دستگاه‌ها", "Total"}] ++ Enum.map(total_branch_values ++ total_fixed_values, &{&1, "Total"})]
  end

  defp loan_details_sheet_rows(loans) do
    headers = [
      "ردیف",
      "نوع دستگاه",
      "پلاک",
      "QR Code",
      "شعبه مالک",
      "محل امانت",
      "تاریخ امانت",
      "توضیحات"
    ]

    rows =
      loans
      |> Enum.with_index(1)
      |> Enum.map(fn {loan, index} ->
        scooter = loan.scooter

        [
          index,
          device_type_label(scooter.device_type),
          scooter.plate || "-",
          scooter.barcode || "-",
          if(scooter.branch, do: scooter.branch.name, else: "-"),
          loan.unit_name || "-",
          Beroon.Calendar.persian_datetime(loan.loaned_at),
          loan.notes || "-"
        ]
      end)

    empty_rows =
      if loans == [] do
        [[{"در حال حاضر دستگاه امانی فعالی ثبت نشده است.", "Subtitle"}]]
      else
        []
      end

    [
      [{"فهرست دستگاه‌های امانی", "Title"}],
      [{"تاریخ تهیه گزارش: #{Beroon.Calendar.persian_datetime(DateTime.utc_now())}", "Subtitle"}],
      [],
      Enum.map(headers, &{&1, "Header"})
    ] ++ rows ++ empty_rows
  end

  defp workshop_discharge_sheet_rows(date) do
    discharges = Reports.workshop_discharges_for_date(date)
    technicians = ["محب صافی", "احسان طیاری", "میثاق پرتو"]

    detail_rows =
      discharges
      |> Enum.with_index(1)
      |> Enum.map(fn {item, index} ->
        type_label =
          [item.device_type.category, item.device_type.device_model, item.device_type.device_identifier]
          |> Enum.reject(&(&1 in [nil, ""]))
          |> Enum.join(" ")

        [
          index,
          item.plate || "-",
          type_label,
          item.repair_parts_used || "-",
          item.technician_name || "ثبت نشده",
          Beroon.Calendar.persian_datetime(item.discharged_at)
        ]
      end)

    technician_rows =
      Enum.map(technicians, fn technician ->
        count = Enum.count(discharges, &(&1.technician_name == technician))
        [{"تعداد ترخیص #{technician}", "Label"}, {count, "Number"}]
      end)

    [
      [{"گزارش ترخیص تعمیرگاه", "Title"}],
      [{"تاریخ گزارش: #{Beroon.Calendar.persian_date(date)}", "Subtitle"}],
      [],
      Enum.map(["ردیف", "پلاک", "نوع دستگاه", "قطعات مصرف‌شده", "تعمیرکار", "زمان ترخیص"], &{&1, "Header"})
    ] ++
      detail_rows ++
      [[], [{"جمع کل ترخیص", "Total"}, {length(discharges), "Total"}]] ++
      technician_rows
  end

  defp summary_sheet_rows(title, date, items) do
    rows =
      Enum.map(items, fn {label, value} ->
        [{label, "Label"}, {value, "Number"}]
      end)

    [
      [{title, "Title"}],
      [{"تاریخ گزارش: #{Beroon.Calendar.persian_date(date)}", "Subtitle"}],
      [{"زمان تولید: #{Beroon.Calendar.persian_datetime(DateTime.utc_now())}", "Subtitle"}],
      [],
      [{"عنوان", "Header"}, {"مقدار", "Header"}]
    ] ++ rows
  end

  # Generates a genuine XLSX package instead of SpreadsheetML disguised as .xls.
  # This prevents broken columns, RTL issues and warning dialogs in modern Excel.
  defp xlsx_workbook(worksheets) do
    worksheet_entries =
      worksheets
      |> Enum.with_index(1)
      |> Enum.map(fn {{_name, rows}, index} ->
        {"xl/worksheets/sheet#{index}.xml", xlsx_sheet_xml(rows)}
      end)

    entries =
      [
        {"[Content_Types].xml", xlsx_content_types_xml(length(worksheets))},
        {"_rels/.rels", xlsx_root_rels_xml()},
        {"xl/workbook.xml", xlsx_workbook_xml(worksheets)},
        {"xl/_rels/workbook.xml.rels", xlsx_workbook_rels_xml(length(worksheets))},
        {"xl/styles.xml", xlsx_styles_xml()}
      ] ++ worksheet_entries

    zip_entries =
      Enum.map(entries, fn {name, content} ->
        {String.to_charlist(name), IO.iodata_to_binary(content)}
      end)

    case :zip.create(~c"beroon-report.xlsx", zip_entries, [:memory]) do
      {:ok, {_filename, binary}} -> binary
      {:error, reason} -> raise "ساخت فایل Excel ناموفق بود: #{inspect(reason)}"
    end
  end

  defp xlsx_sheet_xml(rows) do
    max_columns = rows |> Enum.map(&length/1) |> Enum.max(fn -> 1 end)
    max_rows = max(length(rows), 1)
    last_cell = "#{xlsx_column_name(max_columns)}#{max_rows}"

    row_xml =
      rows
      |> Enum.with_index(1)
      |> Enum.map(fn {row, row_index} ->
        cells =
          row
          |> Enum.with_index(1)
          |> Enum.map(fn {cell, column_index} ->
            xlsx_cell_xml(cell, "#{xlsx_column_name(column_index)}#{row_index}")
          end)

        ~s(<row r="#{row_index}">#{IO.iodata_to_binary(cells)}</row>)
      end)

    columns =
      1..max_columns
      |> Enum.map(fn index ->
        width = if index == 1, do: 30, else: 16
        ~s(<col min="#{index}" max="#{index}" width="#{width}" customWidth="1"/>)
      end)

    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
      <dimension ref="A1:#{last_cell}"/>
      <sheetViews>
        <sheetView workbookViewId="0" rightToLeft="1">
          <pane ySplit="4" topLeftCell="A5" activePane="bottomLeft" state="frozen"/>
        </sheetView>
      </sheetViews>
      <sheetFormatPr defaultRowHeight="18"/>
      <cols>#{IO.iodata_to_binary(columns)}</cols>
      <sheetData>#{IO.iodata_to_binary(row_xml)}</sheetData>
      <autoFilter ref="A4:#{xlsx_column_name(max_columns)}#{max_rows}"/>
    </worksheet>
    """
  end

  defp xlsx_cell_xml({value, style}, reference) do
    xlsx_cell_xml(value, reference, xlsx_style_index(style))
  end

  defp xlsx_cell_xml(value, reference) do
    xlsx_cell_xml(value, reference, 0)
  end

  defp xlsx_cell_xml(value, reference, style_index) when is_number(value) do
    ~s(<c r="#{reference}" s="#{style_index}"><v>#{value}</v></c>)
  end

  defp xlsx_cell_xml(value, reference, style_index) do
    text = xml_escape(value)
    ~s(<c r="#{reference}" s="#{style_index}" t="inlineStr"><is><t xml:space="preserve">#{text}</t></is></c>)
  end

  defp xlsx_style_index("Title"), do: 1
  defp xlsx_style_index("Subtitle"), do: 2
  defp xlsx_style_index("Header"), do: 3
  defp xlsx_style_index("Total"), do: 4
  defp xlsx_style_index("Label"), do: 5
  defp xlsx_style_index("Number"), do: 6
  defp xlsx_style_index(_), do: 0

  defp xlsx_column_name(index) when index > 0 do
    do_xlsx_column_name(index, "")
  end

  defp do_xlsx_column_name(0, acc), do: acc

  defp do_xlsx_column_name(index, acc) do
    remainder = rem(index - 1, 26)
    letter = <<?A + remainder>>
    do_xlsx_column_name(div(index - 1, 26), letter <> acc)
  end

  defp xlsx_content_types_xml(sheet_count) do
    sheets =
      Enum.map(1..sheet_count, fn index ->
        ~s(<Override PartName="/xl/worksheets/sheet#{index}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>)
      end)

    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
      <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
      <Default Extension="xml" ContentType="application/xml"/>
      <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
      <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
      #{IO.iodata_to_binary(sheets)}
    </Types>
    """
  end

  defp xlsx_root_rels_xml do
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
    </Relationships>
    """
  end

  defp xlsx_workbook_xml(worksheets) do
    sheets =
      worksheets
      |> Enum.with_index(1)
      |> Enum.map(fn {{name, _rows}, index} ->
        ~s(<sheet name="#{xml_escape(name)}" sheetId="#{index}" r:id="rId#{index}"/>)
      end)

    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
      <bookViews><workbookView rightToLeft="1"/></bookViews>
      <sheets>#{IO.iodata_to_binary(sheets)}</sheets>
    </workbook>
    """
  end

  defp xlsx_workbook_rels_xml(sheet_count) do
    sheets =
      Enum.map(1..sheet_count, fn index ->
        ~s(<Relationship Id="rId#{index}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet#{index}.xml"/>)
      end)

    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      #{IO.iodata_to_binary(sheets)}
      <Relationship Id="rId#{sheet_count + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
    </Relationships>
    """
  end

  defp xlsx_styles_xml do
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
      <fonts count="3">
        <font><sz val="10"/><name val="Tahoma"/></font>
        <font><b/><sz val="14"/><name val="Tahoma"/></font>
        <font><b/><sz val="10"/><name val="Tahoma"/></font>
      </fonts>
      <fills count="4">
        <fill><patternFill patternType="none"/></fill>
        <fill><patternFill patternType="gray125"/></fill>
        <fill><patternFill patternType="solid"><fgColor rgb="FFCCF1EE"/><bgColor indexed="64"/></patternFill></fill>
        <fill><patternFill patternType="solid"><fgColor rgb="FFE9F7F5"/><bgColor indexed="64"/></patternFill></fill>
      </fills>
      <borders count="3">
        <border><left/><right/><top/><bottom/><diagonal/></border>
        <border><left style="thin"/><right style="thin"/><top style="thin"/><bottom style="thin"/><diagonal/></border>
        <border><left/><right/><top style="medium"/><bottom/><diagonal/></border>
      </borders>
      <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
      <cellXfs count="7">
        <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>
        <xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyAlignment="1"><alignment horizontal="right" vertical="center"/></xf>
        <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0" applyAlignment="1"><alignment horizontal="right" vertical="center"/></xf>
        <xf numFmtId="0" fontId="2" fillId="2" borderId="1" xfId="0" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf>
        <xf numFmtId="0" fontId="2" fillId="3" borderId="2" xfId="0" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>
        <xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyAlignment="1"><alignment horizontal="right" vertical="center"/></xf>
        <xf numFmtId="1" fontId="0" fillId="0" borderId="0" xfId="0" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>
      </cellXfs>
      <cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
    </styleSheet>
    """
  end

  defp xml_escape(nil), do: ""

  defp xml_escape(value) do
    value
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end

  defp device_type_label(nil), do: "-"

  defp device_type_label(device_type) do
    [device_type.category, device_type.device_model, device_type.device_identifier]
    |> Enum.map(&(to_string(&1 || "") |> String.trim()))
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" ")
    |> case do
      "" -> "-"
      label -> label
    end
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

  defp parse_money(value) do
    normalized = value |> to_string() |> String.replace(",", "") |> String.trim()

    case Integer.parse(normalized) do
      {number, ""} when number >= 0 -> number
      {number, _rest} when number >= 0 -> number
      _ -> 0
    end
  end

  defp record_workshop_event(scooter_id, event_type, phone, extra \\ %{}) do
    attrs = %{
      scooter_id: scooter_id,
      event_type: event_type,
      event_on: Reports.iran_today(),
      event_at: DateTime.utc_now() |> DateTime.truncate(:second),
      registered_by_phone: phone
    }

    Reports.create_workshop_event(Map.merge(attrs, extra))
  end

  defp repair_stats_xls(rows) do
    body =
      rows
      |> Enum.map(fn row ->
        "<tr><td>#{Beroon.Calendar.persian_numeric_date(row.date)}</td><td>#{row.accepted}</td><td>#{row.repair_started}</td><td>#{row.discharged}</td></tr>"
      end)
      |> Enum.join()

    "<!doctype html><html><head><meta charset=\"utf-8\"></head><body><table border=\"1\"><thead><tr><th>تاریخ</th><th>پذیرش</th><th>شروع تعمیر</th><th>ترخیص</th></tr></thead><tbody>#{body}</tbody></table></body></html>"
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
      waiting_for_part: Map.get(by_status, "waiting_for_part", 0)
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
      workshop = Operations.list_active_workshops() |> List.first()

      scooter_attrs =
        %{status: "needs_service", notes: notes}
        |> then(fn attrs ->
          if workshop, do: Map.put(attrs, :current_branch_id, workshop.id), else: attrs
        end)

      updated_scooter =
        case Fleet.update_scooter(scooter, scooter_attrs) do
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
    workshop = Operations.get_workshop_for_manager_phone(conn.assigns.current_user_phone)

    if workshop do
      scooter = Fleet.get_scooter!(id)
      attrs = Map.merge(%{status: status, current_branch_id: workshop.id}, extra_attrs)

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

  defp manager_scooters_title(_status), do: "لیست دستگاه‌های شعبه من"
end
