defmodule BeroonWeb.BranchControllerTest do
  use BeroonWeb.ConnCase

  import Beroon.OperationsFixtures

  setup %{conn: conn}, do: {:ok, conn: log_in_admin(conn)}

  @create_attrs %{
    active: true,
    code: "some code",
    name: "some name",
    manager_name: "some manager_name"
  }
  @update_attrs %{
    active: false,
    code: "some updated code",
    name: "some updated name",
    manager_name: "some updated manager_name"
  }
  @invalid_attrs %{active: nil, code: nil, name: nil, manager_name: nil}

  describe "index" do
    test "lists all branches", %{conn: conn} do
      conn = get(conn, ~p"/branches")
      assert html_response(conn, 200) =~ "شعبه‌ها"
    end
  end

  describe "new branch" do
    test "renders form", %{conn: conn} do
      conn = get(conn, ~p"/branches/new")
      assert html_response(conn, 200) =~ "شعبه جدید"
    end
  end

  describe "create branch" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/branches", branch: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/branches/#{id}"

      conn = get(conn, ~p"/branches/#{id}")
      assert html_response(conn, 200) =~ "some name"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/branches", branch: @invalid_attrs)
      assert html_response(conn, 200) =~ "شعبه جدید"
    end
  end

  describe "edit branch" do
    setup [:create_branch]

    test "renders form for editing chosen branch", %{conn: conn, branch: branch} do
      conn = get(conn, ~p"/branches/#{branch}/edit")
      assert html_response(conn, 200) =~ "ویرایش شعبه"
    end
  end

  describe "update branch" do
    setup [:create_branch]

    test "redirects when data is valid", %{conn: conn, branch: branch} do
      conn = put(conn, ~p"/branches/#{branch}", branch: @update_attrs)
      assert redirected_to(conn) == ~p"/branches/#{branch}"

      conn = get(conn, ~p"/branches/#{branch}")
      assert html_response(conn, 200) =~ "some updated name"
    end

    test "renders errors when data is invalid", %{conn: conn, branch: branch} do
      conn = put(conn, ~p"/branches/#{branch}", branch: @invalid_attrs)
      assert html_response(conn, 200) =~ "ویرایش شعبه"
    end
  end

  describe "delete branch" do
    setup [:create_branch]

    test "deletes chosen branch", %{conn: conn, branch: branch} do
      conn = delete(conn, ~p"/branches/#{branch}")
      assert redirected_to(conn) == ~p"/branches"

      assert_error_sent 404, fn ->
        get(conn, ~p"/branches/#{branch}")
      end
    end
  end

  defp create_branch(_) do
    branch = branch_fixture()

    %{branch: branch}
  end
end
