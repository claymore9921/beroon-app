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

  test "GET / sends branch manager to manager panel", %{conn: conn} do
    conn =
      conn
      |> log_in_branch_manager()
      |> get(~p"/")

    assert redirected_to(conn) == ~p"/manager"
  end

  test "manager panel greets manager and shows branch device buttons", %{conn: conn} do
    branch_fixture(%{
      name: "باهنر",
      manager_name: "احمد",
      manager_phone: "09120000000"
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
      status: "needs_service",
      notes: "نیاز به بررسی"
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
    refute response =~ "other-active"
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
end
