defmodule BeroonWeb.EveningCountControllerTest do
  use BeroonWeb.ConnCase

  import Beroon.ReportsFixtures

  setup %{conn: conn}, do: {:ok, conn: log_in_admin(conn)}

  @create_attrs %{
    counted_on: ~D[2026-07-01],
    counted_at: ~U[2026-07-01 21:03:00Z],
    manager_name: "some manager_name",
    manager_phone: "09120000000",
    total_count: 42,
    available_count: 42,
    rented_count: 42,
    damaged_count: 42,
    missing_count: 42,
    notes: "some notes"
  }
  @update_attrs %{
    counted_on: ~D[2026-07-02],
    counted_at: ~U[2026-07-02 21:03:00Z],
    manager_name: "some updated manager_name",
    manager_phone: "09120000001",
    total_count: 43,
    available_count: 43,
    rented_count: 43,
    damaged_count: 43,
    missing_count: 43,
    notes: "some updated notes"
  }
  @invalid_attrs %{
    counted_on: nil,
    counted_at: nil,
    manager_name: nil,
    total_count: nil,
    available_count: nil,
    rented_count: nil,
    damaged_count: nil,
    missing_count: nil,
    notes: nil
  }

  describe "index" do
    test "lists all evening_counts", %{conn: conn} do
      conn = get(conn, ~p"/evening_counts")
      assert html_response(conn, 200) =~ "Listing Evening counts"
    end
  end

  describe "new evening_count" do
    test "renders form", %{conn: conn} do
      conn = get(conn, ~p"/evening_counts/new")
      assert html_response(conn, 200) =~ "New Evening count"
    end
  end

  describe "create evening_count" do
    test "redirects to show when data is valid", %{conn: conn} do
      branch =
        Beroon.OperationsFixtures.branch_fixture(%{
          code: "evening controller",
          name: "evening controller"
        })

      conn =
        post(conn, ~p"/evening_counts",
          evening_count: Map.put(@create_attrs, :branch_id, branch.id)
        )

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/evening_counts/#{id}"

      conn = get(conn, ~p"/evening_counts/#{id}")
      assert html_response(conn, 200) =~ "Evening count #{id}"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/evening_counts", evening_count: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Evening count"
    end
  end

  describe "edit evening_count" do
    setup [:create_evening_count]

    test "renders form for editing chosen evening_count", %{
      conn: conn,
      evening_count: evening_count
    } do
      conn = get(conn, ~p"/evening_counts/#{evening_count}/edit")
      assert html_response(conn, 200) =~ "Edit Evening count"
    end
  end

  describe "update evening_count" do
    setup [:create_evening_count]

    test "redirects when data is valid", %{conn: conn, evening_count: evening_count} do
      conn = put(conn, ~p"/evening_counts/#{evening_count}", evening_count: @update_attrs)
      assert redirected_to(conn) == ~p"/evening_counts/#{evening_count}"

      conn = get(conn, ~p"/evening_counts/#{evening_count}")
      assert html_response(conn, 200) =~ "some updated manager_name"
    end

    test "renders errors when data is invalid", %{conn: conn, evening_count: evening_count} do
      conn = put(conn, ~p"/evening_counts/#{evening_count}", evening_count: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Evening count"
    end
  end

  describe "delete evening_count" do
    setup [:create_evening_count]

    test "deletes chosen evening_count", %{conn: conn, evening_count: evening_count} do
      conn = delete(conn, ~p"/evening_counts/#{evening_count}")
      assert redirected_to(conn) == ~p"/evening_counts"

      assert_error_sent 404, fn ->
        get(conn, ~p"/evening_counts/#{evening_count}")
      end
    end
  end

  defp create_evening_count(_) do
    evening_count = evening_count_fixture()

    %{evening_count: evening_count}
  end
end
