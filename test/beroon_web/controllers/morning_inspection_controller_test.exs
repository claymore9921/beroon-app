defmodule BeroonWeb.MorningInspectionControllerTest do
  use BeroonWeb.ConnCase

  import Beroon.ReportsFixtures

  setup %{conn: conn}, do: {:ok, conn: log_in_admin(conn)}

  @create_attrs %{
    status: "some status",
    checked_on: ~D[2026-07-01],
    checked_at: ~U[2026-07-01 21:03:00Z],
    manager_name: "some manager_name",
    manager_phone: "09120000000",
    notes: "some notes",
    submitted_before_deadline: true
  }
  @update_attrs %{
    status: "some updated status",
    checked_on: ~D[2026-07-02],
    checked_at: ~U[2026-07-02 21:03:00Z],
    manager_name: "some updated manager_name",
    manager_phone: "09120000001",
    notes: "some updated notes",
    submitted_before_deadline: false
  }
  @invalid_attrs %{
    status: nil,
    checked_on: nil,
    checked_at: nil,
    manager_name: nil,
    notes: nil,
    submitted_before_deadline: nil
  }

  describe "index" do
    test "lists all morning_inspections", %{conn: conn} do
      conn = get(conn, ~p"/morning_inspections")
      assert html_response(conn, 200) =~ "Listing Morning inspections"
    end
  end

  describe "new morning_inspection" do
    test "renders form", %{conn: conn} do
      conn = get(conn, ~p"/morning_inspections/new")
      assert html_response(conn, 200) =~ "New Morning inspection"
    end
  end

  describe "create morning_inspection" do
    test "redirects to show when data is valid", %{conn: conn} do
      branch =
        Beroon.OperationsFixtures.branch_fixture(%{
          code: "morning controller",
          name: "morning controller"
        })

      scooter = Beroon.FleetFixtures.scooter_fixture(%{branch_id: branch.id})

      attrs =
        @create_attrs
        |> Map.put(:branch_id, branch.id)
        |> Map.put(:scooter_id, scooter.id)

      conn = post(conn, ~p"/morning_inspections", morning_inspection: attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/morning_inspections/#{id}"

      conn = get(conn, ~p"/morning_inspections/#{id}")
      assert html_response(conn, 200) =~ "Morning inspection #{id}"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/morning_inspections", morning_inspection: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Morning inspection"
    end
  end

  describe "edit morning_inspection" do
    setup [:create_morning_inspection]

    test "renders form for editing chosen morning_inspection", %{
      conn: conn,
      morning_inspection: morning_inspection
    } do
      conn = get(conn, ~p"/morning_inspections/#{morning_inspection}/edit")
      assert html_response(conn, 200) =~ "Edit Morning inspection"
    end
  end

  describe "update morning_inspection" do
    setup [:create_morning_inspection]

    test "redirects when data is valid", %{conn: conn, morning_inspection: morning_inspection} do
      conn =
        put(conn, ~p"/morning_inspections/#{morning_inspection}",
          morning_inspection: @update_attrs
        )

      assert redirected_to(conn) == ~p"/morning_inspections/#{morning_inspection}"

      conn = get(conn, ~p"/morning_inspections/#{morning_inspection}")
      assert html_response(conn, 200) =~ "some updated manager_name"
    end

    test "renders errors when data is invalid", %{
      conn: conn,
      morning_inspection: morning_inspection
    } do
      conn =
        put(conn, ~p"/morning_inspections/#{morning_inspection}",
          morning_inspection: @invalid_attrs
        )

      assert html_response(conn, 200) =~ "Edit Morning inspection"
    end
  end

  describe "delete morning_inspection" do
    setup [:create_morning_inspection]

    test "deletes chosen morning_inspection", %{
      conn: conn,
      morning_inspection: morning_inspection
    } do
      conn = delete(conn, ~p"/morning_inspections/#{morning_inspection}")
      assert redirected_to(conn) == ~p"/morning_inspections"

      assert_error_sent 404, fn ->
        get(conn, ~p"/morning_inspections/#{morning_inspection}")
      end
    end
  end

  defp create_morning_inspection(_) do
    morning_inspection = morning_inspection_fixture()

    %{morning_inspection: morning_inspection}
  end
end
