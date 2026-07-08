defmodule BeroonWeb.PageControllerTest do
  use BeroonWeb.ConnCase

  import Beroon.ChecklistsFixtures
  import Beroon.FleetFixtures
  import Beroon.OperationsFixtures

  test "GET / redirects anonymous users to login", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/login"
  end

  test "GET / sends admin to admin panel", %{conn: conn} do
    conn =
      conn
      |> log_in_admin()
      |> get(~p"/")

    assert redirected_to(conn) == ~p"/admin/reports"
  end

  test "admin panel shows all scooter status boxes", %{conn: conn} do
    branch = branch_fixture()
    device_type = device_type_fixture()

    [
      "active",
      "needs_service",
      "awaiting_repair",
      "repairing",
      "waiting_for_part",
      "ready_for_pickup",
      "out_of_service"
    ]
    |> Enum.with_index()
    |> Enum.each(fn {status, index} ->
      scooter_fixture(%{
        branch_id: branch.id,
        device_type_id: device_type.id,
        barcode: "admin-status-#{index}",
        plate: "ADMIN-STATUS-#{index}",
        status: status,
        notes: if(status in ["needs_service", "waiting_for_part"], do: "note", else: nil)
      })
    end)

    conn =
      conn
      |> log_in_admin()
      |> get(~p"/admin/reports")

    response = html_response(conn, 200)
    assert response =~ "فعال"
    assert response =~ "خراب"
    assert response =~ "در انتظار تعمیر"
    assert response =~ "در حال تعمیر"
    assert response =~ "در انتظار قطعه"
    assert response =~ "آماده تحویل"
    assert response =~ "از مدار خارج شده"
    assert response =~ ~s(class="admin-bottom-nav")
    assert response =~ ~p"/admin/report-export"
    assert response =~ ~p"/admin/evening-reports"
  end

  test "GET / sends branch manager to manager panel", %{conn: conn} do
    conn =
      conn
      |> log_in_branch_manager()
      |> get(~p"/")

    assert redirected_to(conn) == ~p"/manager"
  end

  test "manager scan page shows morning and evening actions", %{conn: conn} do
    branch_fixture(%{
      name: "حافظ",
      manager_name: "محسن",
      manager_phone: "09120000000"
    })

    conn =
      conn
      |> log_in_branch_manager("09120000000")
      |> get(~p"/manager/scan")

    response = html_response(conn, 200)
    assert response =~ "اسکن و ثبت گزارش"
    assert response =~ "چک لیست صبح"
    assert response =~ "آمار شب"
    assert response =~ ~p"/manager/morning"
    assert response =~ ~p"/manager/evening"
  end

  test "manager panel greets manager and shows branch device buttons", %{conn: conn} do
    branch =
      branch_fixture(%{
        name: "باهنر",
        manager_name: "احمد",
        manager_phone: "09120000000"
      })

    device_type = device_type_fixture()

    scooter_fixture(%{
      branch_id: branch.id,
      device_type_id: device_type.id,
      barcode: "workshop-accepted",
      plate: "WORKSHOP-ACCEPTED",
      status: "awaiting_repair"
    })

    conn =
      conn
      |> log_in_branch_manager("09120000000")
      |> get(~p"/manager")

    response = html_response(conn, 200)
    assert response =~ "سلام احمد عزیز!"
    assert response =~ "باهنر"
    assert response =~ "لیست دستگاه‌های شعبه من"
    assert response =~ "دستگاه‌های فعال"
    assert response =~ "تعمیرگاه"
    assert response =~ ~p"/manager/scan"
  end

  test "admin sends notification and branch manager reads it", %{conn: conn} do
    branch =
      branch_fixture(%{
        name: "Notification branch",
        manager_phone: "09120000000"
      })

    conn =
      conn
      |> log_in_admin()
      |> get(~p"/admin/notifications")

    response = html_response(conn, 200)
    assert response =~ "admin-notification-form"
    assert response =~ "Notification branch"

    conn =
      build_conn()
      |> log_in_admin()
      |> post(~p"/admin/notifications",
        notification: %{
          subject: "Service update",
          body: "Message body",
          branch_ids: [to_string(branch.id)]
        }
      )

    assert redirected_to(conn) == ~p"/admin/notifications"

    conn =
      build_conn()
      |> log_in_branch_manager(branch.manager_phone)
      |> get(~p"/manager")

    response = html_response(conn, 200)
    assert response =~ ~p"/manager/notifications"
    assert response =~ ~s(class="beroon-header-bell")

    conn =
      build_conn()
      |> log_in_branch_manager(branch.manager_phone)
      |> get(~p"/manager/notifications")

    response = html_response(conn, 200)
    assert response =~ "Service update"
    assert response =~ "is-unread"
    [recipient] = Beroon.Reports.list_branch_notifications(branch.id)

    conn =
      build_conn()
      |> log_in_branch_manager(branch.manager_phone)
      |> get(~p"/manager/notifications/#{recipient.id}")

    response = html_response(conn, 200)
    assert response =~ "Service update"
    assert response =~ "Message body"
    assert Beroon.Reports.count_unread_branch_notifications(branch.id) == 0
  end

  test "manager scooter list is scoped to manager branch and status", %{conn: conn} do
    manager_branch =
      branch_fixture(%{
        name: "باهنر",
        manager_name: "احمد",
        manager_phone: "09120000000"
      })

    other_branch = branch_fixture(%{name: "ونک", manager_phone: "09129999999"})
    device_type = device_type_fixture()

    scooter_fixture(%{
      branch_id: manager_branch.id,
      device_type_id: device_type.id,
      barcode: "manager-active",
      plate: "manager-active",
      status: "active"
    })

    scooter_fixture(%{
      branch_id: manager_branch.id,
      device_type_id: device_type.id,
      barcode: "manager-repair",
      plate: "manager-repair",
      status: "awaiting_repair"
    })

    scooter_fixture(%{
      branch_id: manager_branch.id,
      device_type_id: device_type.id,
      barcode: "manager-repairing",
      plate: "manager-repairing",
      status: "repairing"
    })

    scooter_fixture(%{
      branch_id: manager_branch.id,
      device_type_id: device_type.id,
      barcode: "manager-waiting-part",
      plate: "manager-waiting-part",
      status: "waiting_for_part",
      notes: "part"
    })

    scooter_fixture(%{
      branch_id: other_branch.id,
      device_type_id: device_type.id,
      barcode: "other-active",
      plate: "other-active",
      status: "active"
    })

    conn =
      conn
      |> log_in_branch_manager("09120000000")
      |> get(~p"/manager/scooters/active")

    response = html_response(conn, 200)
    assert response =~ "manager-active"
    refute response =~ "manager-repair"
    refute response =~ "manager-repairing"
    refute response =~ "other-active"

    conn =
      build_conn()
      |> log_in_branch_manager("09120000000")
      |> get(~p"/manager/scooters/workshop")

    response = html_response(conn, 200)
    assert response =~ "manager-repair"
    assert response =~ "manager-repairing"
    refute response =~ "manager-waiting-part"
    refute response =~ "manager-active"
    refute response =~ "other-active"
  end

  test "branch manager sends damaged scooter to workshop", %{conn: conn} do
    branch = branch_fixture(%{manager_phone: "09120000000"})
    device_type = device_type_fixture()

    scooter =
      scooter_fixture(%{
        branch_id: branch.id,
        device_type_id: device_type.id,
        barcode: "damage-1",
        plate: "DAMAGE-1",
        status: "active"
      })

    conn =
      conn
      |> log_in_branch_manager("09120000000")
      |> post(~p"/manager/repairs/#{scooter}/send", repair: %{notes: "broken brake"})

    assert redirected_to(conn) == ~p"/manager/repairs?q=DAMAGE-1"
    assert Beroon.Fleet.get_scooter!(scooter.id).status == "needs_service"
    assert Beroon.Fleet.get_scooter!(scooter.id).notes == "broken brake"
  end

  test "manager repairs page lists only active branch scooters", %{conn: conn} do
    branch = branch_fixture(%{manager_phone: "09120000000"})
    device_type = device_type_fixture()

    scooter_fixture(%{
      branch_id: branch.id,
      device_type_id: device_type.id,
      barcode: "repair-active",
      plate: "REPAIR-ACTIVE",
      status: "active"
    })

    scooter_fixture(%{
      branch_id: branch.id,
      device_type_id: device_type.id,
      barcode: "repair-damaged",
      plate: "REPAIR-DAMAGED",
      status: "needs_service",
      notes: "broken"
    })

    scooter_fixture(%{
      branch_id: branch.id,
      device_type_id: device_type.id,
      barcode: "repair-awaiting",
      plate: "REPAIR-AWAITING",
      status: "awaiting_repair"
    })

    conn =
      conn
      |> log_in_branch_manager("09120000000")
      |> get(~p"/manager/repairs")

    response = html_response(conn, 200)
    assert response =~ "REPAIR-ACTIVE"
    refute response =~ "REPAIR-DAMAGED"
    refute response =~ "REPAIR-AWAITING"
  end

  test "manager repairs page shows ready for pickup alert for branch scooters", %{conn: conn} do
    branch = branch_fixture(%{manager_phone: "09120000000"})
    other_branch = branch_fixture(%{manager_phone: "09129999999"})
    device_type = device_type_fixture()

    scooter_fixture(%{
      branch_id: branch.id,
      device_type_id: device_type.id,
      barcode: "ready-local",
      plate: "READY-LOCAL",
      status: "ready_for_pickup"
    })

    scooter_fixture(%{
      branch_id: other_branch.id,
      device_type_id: device_type.id,
      barcode: "ready-other",
      plate: "READY-OTHER",
      status: "ready_for_pickup"
    })

    conn =
      conn
      |> log_in_branch_manager("09120000000")
      |> get(~p"/manager/repairs")

    response = html_response(conn, 200)
    assert response =~ ~s(id="ready-for-pickup-box")
    assert response =~ "ترخیص‌شده از تعمیرگاه"
    assert response =~ "READY-LOCAL"
    refute response =~ "READY-OTHER"
  end

  test "workshop discharges scooter for branch pickup and manager receives it", %{conn: conn} do
    workshop = branch_fixture(%{kind: "workshop", manager_phone: "09130000000"})
    branch = branch_fixture(%{manager_phone: "09120000000"})
    device_type = device_type_fixture()

    scooter =
      scooter_fixture(%{
        branch_id: branch.id,
        device_type_id: device_type.id,
        barcode: "repair-1",
        plate: "REPAIR-1",
        status: "needs_service",
        notes: "needs repair"
      })

    conn =
      conn
      |> log_in_workshop_manager(workshop.manager_phone)
      |> post(~p"/workshop/scooters/#{scooter}/accept")

    assert redirected_to(conn) == ~p"/workshop/acceptance"
    assert Beroon.Fleet.get_scooter!(scooter.id).status == "awaiting_repair"

    conn =
      build_conn()
      |> log_in_workshop_manager(workshop.manager_phone)
      |> post(~p"/workshop/scooters/#{scooter}/start")

    assert redirected_to(conn) == ~p"/workshop/repairing"
    assert Beroon.Fleet.get_scooter!(scooter.id).status == "repairing"

    conn =
      build_conn()
      |> log_in_workshop_manager(workshop.manager_phone)
      |> post(~p"/workshop/scooters/#{scooter}/discharge")

    assert redirected_to(conn) == ~p"/workshop/discharge"
    assert Beroon.Fleet.get_scooter!(scooter.id).status == "ready_for_pickup"

    conn =
      build_conn()
      |> log_in_branch_manager(branch.manager_phone)
      |> post(~p"/manager/repairs/receive", receive: %{plate: scooter.plate})

    assert redirected_to(conn) == ~p"/manager/repairs/receive"
    assert Beroon.Fleet.get_scooter!(scooter.id).status == "active"
  end

  test "workshop pages are split and searchable by plate", %{conn: conn} do
    workshop = branch_fixture(%{kind: "workshop", manager_phone: "09130000000"})
    branch = branch_fixture()
    device_type = device_type_fixture()

    scooter_fixture(%{
      branch_id: branch.id,
      device_type_id: device_type.id,
      barcode: "accept-search",
      plate: "ACCEPT-1",
      status: "needs_service",
      notes: "broken"
    })

    scooter_fixture(%{
      branch_id: branch.id,
      device_type_id: device_type.id,
      barcode: "repair-search",
      plate: "REPAIR-1",
      status: "repairing"
    })

    scooter_fixture(%{
      branch_id: branch.id,
      device_type_id: device_type.id,
      barcode: "other-search",
      plate: "OTHER-1",
      status: "active"
    })

    conn =
      conn
      |> log_in_workshop_manager(workshop.manager_phone)
      |> get(~p"/workshop")

    response = html_response(conn, 200)
    assert response =~ ~p"/workshop/acceptance"
    assert response =~ ~p"/workshop/repairing"
    assert response =~ ~p"/workshop/discharge"

    conn =
      build_conn()
      |> log_in_workshop_manager(workshop.manager_phone)
      |> get(~p"/workshop/acceptance?q=ACCEPT")

    response = html_response(conn, 200)
    assert response =~ "ACCEPT-1"
    refute response =~ "REPAIR-1"
    refute response =~ "OTHER-1"

    conn =
      build_conn()
      |> log_in_workshop_manager(workshop.manager_phone)
      |> get(~p"/workshop/discharge?q=REPAIR")

    response = html_response(conn, 200)
    assert response =~ "REPAIR-1"
    refute response =~ "ACCEPT-1"
    refute response =~ "OTHER-1"
  end

  test "workshop info ranks branches by repair report counts", %{conn: conn} do
    workshop = branch_fixture(%{kind: "workshop", manager_phone: "09130000000"})
    busy_branch = branch_fixture(%{name: "Busy branch", manager_phone: "09120000000"})
    quiet_branch = branch_fixture(%{name: "Quiet branch", manager_phone: "09120000001"})
    unreported_branch = branch_fixture(%{name: "Unreported branch"})
    device_type = device_type_fixture()

    busy_scooter =
      scooter_fixture(%{
        branch_id: busy_branch.id,
        device_type_id: device_type.id,
        barcode: "busy-repeated",
        plate: "BUSY-1",
        status: "active"
      })

    quiet_scooter =
      scooter_fixture(%{
        branch_id: quiet_branch.id,
        device_type_id: device_type.id,
        barcode: "quiet-once",
        plate: "QUIET-1",
        status: "active"
      })

    scooter_fixture(%{
      branch_id: unreported_branch.id,
      device_type_id: device_type.id,
      barcode: "unreported-needs-service",
      plate: "UNREPORTED-1",
      status: "needs_service",
      notes: "broken without report"
    })

    conn
    |> log_in_branch_manager(busy_branch.manager_phone)
    |> post(~p"/manager/repairs/#{busy_scooter}/send", repair: %{notes: "first failure"})

    build_conn()
    |> log_in_branch_manager(busy_branch.manager_phone)
    |> post(~p"/manager/repairs/#{busy_scooter}/send", repair: %{notes: "second failure"})

    build_conn()
    |> log_in_branch_manager(quiet_branch.manager_phone)
    |> post(~p"/manager/repairs/#{quiet_scooter}/send", repair: %{notes: "one failure"})

    conn =
      build_conn()
      |> log_in_workshop_manager(workshop.manager_phone)
      |> get(~p"/workshop/info")

    response = html_response(conn, 200)
    assert response =~ ~s(class="workshop-bottom-nav")
    assert response =~ "Busy branch"
    assert response =~ "Quiet branch"
    assert response =~ "2"
    assert response =~ "1"
    refute response =~ "Unreported branch"
    assert :binary.match(response, "Busy branch") < :binary.match(response, "Quiet branch")
  end

  test "legacy workshop info status counts are ignored without repair reports", %{conn: conn} do
    workshop = branch_fixture(%{kind: "workshop", manager_phone: "09130000000"})
    branch = branch_fixture(%{name: "Status-only branch"})
    device_type = device_type_fixture()

    scooter_fixture(%{
      branch_id: branch.id,
      device_type_id: device_type.id,
      barcode: "status-only-needs-service",
      plate: "STATUS-ONLY-1",
      status: "needs_service",
      notes: "broken"
    })

    conn =
      conn
      |> log_in_workshop_manager(workshop.manager_phone)
      |> get(~p"/workshop/info")

    response = html_response(conn, 200)
    refute response =~ "Status-only branch"
  end

  test "manager morning checklist shows selected branch scooter", %{conn: conn} do
    branch = branch_fixture(%{manager_name: "احمد", manager_phone: "09120000000"})
    device_type = device_type_fixture()
    checklist_item_fixture(%{title: "ترمز", active: true})

    scooter =
      scooter_fixture(%{
        branch_id: branch.id,
        device_type_id: device_type.id,
        barcode: "morning-scan-1",
        plate: "MOR-1"
      })

    conn =
      conn
      |> log_in_branch_manager("09120000000")
      |> get(~p"/manager/morning?code=#{scooter.barcode}")

    response = html_response(conn, 200)
    assert response =~ "morning-device-form"
    assert response =~ "MOR-1"
    assert response =~ "ترمز"
  end

  test "manager morning checklist saves one device and blocks duplicate", %{conn: conn} do
    branch = branch_fixture(%{manager_name: "احمد", manager_phone: "09120000000"})
    device_type = device_type_fixture()
    checklist_item = checklist_item_fixture(%{active: true})

    scooter =
      scooter_fixture(%{
        branch_id: branch.id,
        device_type_id: device_type.id,
        barcode: "morning-save-1",
        plate: "MOR-2"
      })

    params = %{
      scooter_id: scooter.id,
      checklist_item_ids: [checklist_item.id],
      checked_item_ids: [checklist_item.id],
      notes: ""
    }

    conn =
      conn
      |> log_in_branch_manager("09120000000")
      |> post(~p"/manager/morning", morning: params)

    assert redirected_to(conn) == ~p"/manager/morning"

    conn =
      build_conn()
      |> log_in_branch_manager("09120000000")
      |> post(~p"/manager/morning", morning: params)

    assert redirected_to(conn) == ~p"/manager/morning"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "قبلا ثبت شده"
  end

  test "admin checklist branch report shows filtered reports and unchecked alert", %{conn: conn} do
    branch = branch_fixture(%{name: "باهنر"})
    device_type = device_type_fixture(%{device_identifier: "1n1", category: "دوچرخه برقی"})
    checklist_item = checklist_item_fixture(%{title: "ترمز", active: true})

    checked =
      scooter_fixture(%{
        branch_id: branch.id,
        device_type_id: device_type.id,
        barcode: "checked-barcode",
        plate: "CHK-1"
      })

    unchecked =
      scooter_fixture(%{
        branch_id: branch.id,
        device_type_id: device_type.id,
        barcode: "unchecked-barcode",
        plate: "UNCHK-1"
      })

    {:ok, _inspection} =
      Beroon.Reports.create_morning_inspection_with_items(
        %{
          "branch_id" => branch.id,
          "scooter_id" => checked.id,
          "checked_on" => Date.utc_today(),
          "checked_at" => DateTime.utc_now() |> DateTime.truncate(:second),
          "manager_name" => "احمد",
          "manager_phone" => "09120000000",
          "status" => "ready",
          "submitted_before_deadline" => true
        },
        [checklist_item.id],
        [checklist_item.id]
      )

    conn =
      conn
      |> log_in_admin()
      |> get(~p"/admin/checklists/branches/#{branch}?q=checked-barcode")

    response = html_response(conn, 200)
    assert response =~ "checked-barcode"
    assert response =~ "دستگاه‌های چک‌نشده امروز"
    assert response =~ ~s(data-count="1")
    refute response =~ unchecked.barcode
  end

  test "admin unchecked page lists unchecked branch scooters with search", %{conn: conn} do
    branch = branch_fixture(%{name: "باهنر"})
    device_type = device_type_fixture(%{device_identifier: "2n1", category: "اسکوتر برقی"})

    unchecked =
      scooter_fixture(%{
        branch_id: branch.id,
        device_type_id: device_type.id,
        barcode: "remaining-barcode",
        plate: "REM-1"
      })

    scooter_fixture(%{
      branch_id: branch.id,
      device_type_id: device_type.id,
      barcode: "other-unchecked",
      plate: "REM-2"
    })

    conn =
      conn
      |> log_in_admin()
      |> get(~p"/admin/checklists/branches/#{branch}/unchecked?q=#{unchecked.plate}")

    response = html_response(conn, 200)
    assert response =~ "remaining-barcode"
    assert response =~ "2n1"
    refute response =~ "other-unchecked"
  end

  test "admin branch evening reports show branch counts filtered by counted day", %{conn: conn} do
    branch = branch_fixture(%{name: "Evening branch", manager_name: "Evening manager"})
    other_branch = branch_fixture(%{name: "Other branch"})
    device_type = device_type_fixture(%{device_identifier: "EVT", category: "Scooter"})

    scooter =
      scooter_fixture(%{
        branch_id: branch.id,
        device_type_id: device_type.id,
        barcode: "evening-barcode-1",
        plate: "EVN-1"
      })

    old_scooter =
      scooter_fixture(%{
        branch_id: branch.id,
        device_type_id: device_type.id,
        barcode: "evening-barcode-old",
        plate: "EVN-OLD"
      })

    other_scooter =
      scooter_fixture(%{
        branch_id: other_branch.id,
        device_type_id: device_type.id,
        barcode: "other-evening-barcode",
        plate: "OTHER-EVN"
      })

    {:ok, report} =
      Beroon.Reports.create_evening_count_with_items(
        %{
          "branch_id" => branch.id,
          "counted_on" => ~D[2026-07-01],
          "counted_at" => ~U[2026-07-01 21:00:00Z],
          "manager_name" => "Evening manager",
          "manager_phone" => "09120000000",
          "total_count" => 1,
          "available_count" => 1,
          "rented_count" => 0,
          "damaged_count" => 0,
          "missing_count" => 0
        },
        [scooter]
      )

    {:ok, _old_report} =
      Beroon.Reports.create_evening_count_with_items(
        %{
          "branch_id" => branch.id,
          "counted_on" => ~D[2026-06-30],
          "counted_at" => ~U[2026-06-30 21:00:00Z],
          "manager_name" => "Evening manager",
          "manager_phone" => "09120000000",
          "total_count" => 1,
          "available_count" => 1,
          "rented_count" => 0,
          "damaged_count" => 0,
          "missing_count" => 0
        },
        [old_scooter]
      )

    {:ok, _other_report} =
      Beroon.Reports.create_evening_count_with_items(
        %{
          "branch_id" => other_branch.id,
          "counted_on" => ~D[2026-07-01],
          "counted_at" => ~U[2026-07-01 21:00:00Z],
          "manager_name" => "Other manager",
          "manager_phone" => "09129999999",
          "total_count" => 1,
          "available_count" => 1,
          "rented_count" => 0,
          "damaged_count" => 0,
          "missing_count" => 0
        },
        [other_scooter]
      )

    conn =
      conn
      |> log_in_admin()
      |> get(~p"/admin/evening-reports/branches/#{branch}?date=2026-07-01")

    response = html_response(conn, 200)
    assert response =~ Beroon.Calendar.persian_date(~D[2026-07-01])
    assert response =~ ~p"/admin/evening-reports/counts/#{report.id}"
    refute response =~ "EVN-1"
    refute response =~ "EVN-OLD"
    refute response =~ "OTHER-EVN"

    conn =
      build_conn()
      |> log_in_admin()
      |> get(~p"/admin/evening-reports/counts/#{report}")

    response = html_response(conn, 200)
    assert response =~ "EVN-1"
    assert response =~ "evening-barcode-1"
    refute response =~ "EVN-OLD"
    refute response =~ "OTHER-EVN"
  end

  test "admin exports evening inventory excel by date", %{conn: conn} do
    hafez = branch_fixture(%{name: "حافظ", manager_name: "Hafez manager"})
    sepeh = branch_fixture(%{name: "سپه", manager_name: "Sepeh manager"})

    scooter_type =
      device_type_fixture(%{
        device_identifier: "x9",
        category: "اسکوتر سبز",
        device_model: "x9"
      })

    bike_type =
      device_type_fixture(%{
        device_identifier: "h1",
        category: "دوچرخه برقی سبز",
        device_model: "h1"
      })

    hafez_scooter_1 =
      scooter_fixture(%{
        branch_id: hafez.id,
        device_type_id: scooter_type.id,
        barcode: "hafez-scooter-1",
        plate: "H-S-1"
      })

    hafez_scooter_2 =
      scooter_fixture(%{
        branch_id: hafez.id,
        device_type_id: scooter_type.id,
        barcode: "hafez-scooter-2",
        plate: "H-S-2"
      })

    sepeh_scooter =
      scooter_fixture(%{
        branch_id: sepeh.id,
        device_type_id: scooter_type.id,
        barcode: "sepeh-scooter-1",
        plate: "S-S-1"
      })

    hafez_bike =
      scooter_fixture(%{
        branch_id: hafez.id,
        device_type_id: bike_type.id,
        barcode: "hafez-bike-1",
        plate: "H-B-1"
      })

    {:ok, _report} =
      Beroon.Reports.create_evening_count_with_items(
        %{
          "branch_id" => hafez.id,
          "counted_on" => ~D[2026-07-01],
          "counted_at" => ~U[2026-07-01 21:00:00Z],
          "manager_name" => "Hafez manager",
          "manager_phone" => "09120000000",
          "total_count" => 3,
          "available_count" => 3,
          "rented_count" => 0,
          "damaged_count" => 0,
          "missing_count" => 0
        },
        [hafez_scooter_1, hafez_scooter_2, hafez_bike]
      )

    {:ok, _report} =
      Beroon.Reports.create_evening_count_with_items(
        %{
          "branch_id" => sepeh.id,
          "counted_on" => ~D[2026-07-01],
          "counted_at" => ~U[2026-07-01 21:00:00Z],
          "manager_name" => "Sepeh manager",
          "manager_phone" => "09129999999",
          "total_count" => 1,
          "available_count" => 1,
          "rented_count" => 0,
          "damaged_count" => 0,
          "missing_count" => 0
        },
        [sepeh_scooter]
      )

    conn =
      conn
      |> log_in_admin()
      |> get(~p"/admin/report-export")

    response = html_response(conn, 200)
    assert response =~ "خروجی گزارش"
    assert response =~ "admin-report-export-form"

    conn =
      build_conn()
      |> log_in_admin()
      |> get(~p"/admin/report-export/download?date=2026-07-01")

    response = response(conn, 200)
    assert get_resp_header(conn, "content-disposition") |> List.first() =~ ".xls"
    assert response =~ "نوع دستگاه"
    assert response =~ "حافظ"
    assert response =~ "سپه"
    assert response =~ "اسکوتر سبز x9"
    assert response =~ "دوچرخه برقی سبز h1"
    assert response =~ "<td>2</td>"
    assert response =~ "<td>1</td>"
  end
end
