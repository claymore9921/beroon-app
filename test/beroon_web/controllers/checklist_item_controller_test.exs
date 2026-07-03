defmodule BeroonWeb.ChecklistItemControllerTest do
  use BeroonWeb.ConnCase

  import Beroon.ChecklistsFixtures

  setup %{conn: conn}, do: {:ok, conn: log_in_admin(conn)}

  @create_attrs %{
    active: true,
    position: 42,
    description: "some description",
    title: "some title",
    required: true
  }
  @update_attrs %{
    active: false,
    position: 43,
    description: "some updated description",
    title: "some updated title",
    required: false
  }
  @invalid_attrs %{active: nil, position: nil, description: nil, title: nil, required: nil}

  describe "index" do
    test "lists all checklist_items", %{conn: conn} do
      conn = get(conn, ~p"/checklist_items")
      assert html_response(conn, 200) =~ "چک‌لیست‌ها"
    end
  end

  describe "new checklist_item" do
    test "renders form", %{conn: conn} do
      conn = get(conn, ~p"/checklist_items/new")
      assert html_response(conn, 200) =~ "آیتم جدید چک‌لیست"
    end
  end

  describe "create checklist_item" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/checklist_items", checklist_item: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/checklist_items/#{id}"

      conn = get(conn, ~p"/checklist_items/#{id}")
      assert html_response(conn, 200) =~ "some title"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/checklist_items", checklist_item: @invalid_attrs)
      assert html_response(conn, 200) =~ "آیتم جدید چک‌لیست"
    end
  end

  describe "edit checklist_item" do
    setup [:create_checklist_item]

    test "renders form for editing chosen checklist_item", %{
      conn: conn,
      checklist_item: checklist_item
    } do
      conn = get(conn, ~p"/checklist_items/#{checklist_item}/edit")
      assert html_response(conn, 200) =~ "ویرایش آیتم چک‌لیست"
    end
  end

  describe "update checklist_item" do
    setup [:create_checklist_item]

    test "redirects when data is valid", %{conn: conn, checklist_item: checklist_item} do
      conn = put(conn, ~p"/checklist_items/#{checklist_item}", checklist_item: @update_attrs)
      assert redirected_to(conn) == ~p"/checklist_items/#{checklist_item}"

      conn = get(conn, ~p"/checklist_items/#{checklist_item}")
      assert html_response(conn, 200) =~ "some updated title"
    end

    test "renders errors when data is invalid", %{conn: conn, checklist_item: checklist_item} do
      conn = put(conn, ~p"/checklist_items/#{checklist_item}", checklist_item: @invalid_attrs)
      assert html_response(conn, 200) =~ "ویرایش آیتم چک‌لیست"
    end
  end

  describe "delete checklist_item" do
    setup [:create_checklist_item]

    test "deletes chosen checklist_item", %{conn: conn, checklist_item: checklist_item} do
      conn = delete(conn, ~p"/checklist_items/#{checklist_item}")
      assert redirected_to(conn) == ~p"/checklist_items"

      assert_error_sent 404, fn ->
        get(conn, ~p"/checklist_items/#{checklist_item}")
      end
    end
  end

  defp create_checklist_item(_) do
    checklist_item = checklist_item_fixture()

    %{checklist_item: checklist_item}
  end
end
