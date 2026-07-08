defmodule BeroonWeb.ScooterControllerTest do
  use BeroonWeb.ConnCase

  import Beroon.FleetFixtures
  import Beroon.OperationsFixtures

  setup %{conn: conn}, do: {:ok, conn: log_in_admin(conn)}

  @create_attrs %{
    status: "active",
    plate: "some plate",
    barcode: "some barcode",
    model: "some model",
    notes: "some notes"
  }
  @update_attrs %{
    status: "out_of_service",
    plate: "some updated plate",
    barcode: "some updated barcode",
    model: "some updated model",
    notes: "some updated notes"
  }
  @invalid_attrs %{
    status: nil,
    plate: nil,
    barcode: nil,
    model: nil,
    notes: nil,
    device_type_id: nil
  }

  describe "index" do
    test "lists all scooters", %{conn: conn} do
      conn = get(conn, ~p"/scooters")
      response = html_response(conn, 200)

      assert response =~ "دستگاه‌ها"
      assert response =~ "scooter-search-form"
      assert response =~ ~s(class="admin-bottom-nav")
      assert response =~ ~p"/admin/evening-reports"
    end

    test "filters scooters by search query", %{conn: conn} do
      branch = branch_fixture(%{name: "باهنر"})
      device_type = device_type_fixture(%{device_identifier: "1n1", category: "دوچرخه برقی"})

      scooter_fixture(%{
        branch_id: branch.id,
        device_type_id: device_type.id,
        barcode: "barcode-search-match",
        plate: "plate-search-match"
      })

      scooter_fixture(%{
        barcode: "barcode-other",
        plate: "plate-other"
      })

      conn = get(conn, ~p"/scooters?q=باهنر")
      response = html_response(conn, 200)

      assert response =~ "barcode-search-match"
      refute response =~ "barcode-other"
    end
  end

  describe "new scooter" do
    test "renders form", %{conn: conn} do
      conn = get(conn, ~p"/scooters/new")
      assert html_response(conn, 200) =~ "دستگاه جدید"
    end
  end

  describe "create scooter" do
    test "redirects to show when data is valid", %{conn: conn} do
      branch = branch_fixture()
      device_type = device_type_fixture()

      attrs =
        @create_attrs
        |> Map.put(:branch_id, branch.id)
        |> Map.put(:device_type_id, device_type.id)

      conn = post(conn, ~p"/scooters", scooter: attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/scooters/#{id}"

      conn = get(conn, ~p"/scooters/#{id}")
      assert html_response(conn, 200) =~ "some plate"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/scooters", scooter: @invalid_attrs)
      assert html_response(conn, 200) =~ "دستگاه جدید"
    end
  end

  describe "edit scooter" do
    setup [:create_scooter]

    test "renders form for editing chosen scooter", %{conn: conn, scooter: scooter} do
      conn = get(conn, ~p"/scooters/#{scooter}/edit")
      assert html_response(conn, 200) =~ "ویرایش دستگاه"
    end
  end

  describe "update scooter" do
    setup [:create_scooter]

    test "redirects when data is valid", %{conn: conn, scooter: scooter} do
      conn = put(conn, ~p"/scooters/#{scooter}", scooter: @update_attrs)
      assert redirected_to(conn) == ~p"/scooters/#{scooter}"

      conn = get(conn, ~p"/scooters/#{scooter}")
      assert html_response(conn, 200) =~ "some updated plate"
    end

    test "renders errors when data is invalid", %{conn: conn, scooter: scooter} do
      conn = put(conn, ~p"/scooters/#{scooter}", scooter: @invalid_attrs)
      assert html_response(conn, 200) =~ "ویرایش دستگاه"
    end

    test "admin quickly updates scooter status from index", %{conn: conn, scooter: scooter} do
      conn =
        put(conn, ~p"/scooters/#{scooter}/status", scooter: %{status: "needs_service"}, q: "some")

      assert redirected_to(conn) == ~p"/scooters?q=some"

      scooter = Beroon.Fleet.get_scooter!(scooter.id)
      assert scooter.status == "needs_service"
      assert scooter.notes == "some notes"
    end
  end

  describe "delete scooter" do
    setup [:create_scooter]

    test "deletes chosen scooter", %{conn: conn, scooter: scooter} do
      conn = delete(conn, ~p"/scooters/#{scooter}")
      assert redirected_to(conn) == ~p"/scooters"

      assert_error_sent 404, fn ->
        get(conn, ~p"/scooters/#{scooter}")
      end
    end
  end

  defp create_scooter(_) do
    scooter = scooter_fixture()

    %{scooter: scooter}
  end
end
