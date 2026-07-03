defmodule BeroonWeb.AdminSessionControllerTest do
  use BeroonWeb.ConnCase

  import Beroon.OperationsFixtures

  test "login form renders", %{conn: conn} do
    conn = get(conn, ~p"/login")
    assert html_response(conn, 200) =~ "ورود"
  end

  test "requesting OTP accepts manager and admin phones", %{conn: conn} do
    conn = post(conn, ~p"/login", otp: %{phone: "09120000000"})
    assert redirected_to(conn) == ~p"/verify?phone=09120000000"

    conn = post(build_conn(), ~p"/login", otp: %{phone: "09399644901"})
    assert redirected_to(conn) == ~p"/verify?phone=09399644901"
  end

  test "confirming OTP logs admin in and redirects to admin panel", %{conn: conn} do
    post(conn, ~p"/login", otp: %{phone: "09399644901"})

    conn =
      build_conn()
      |> post(~p"/verify", otp: %{phone: "09399644901", code: "123456"})

    assert get_session(conn, :user_phone) == "09399644901"
    assert get_session(conn, :user_role) == "admin"
    assert redirected_to(conn) == ~p"/admin/reports"
  end

  test "confirming OTP sends unapproved branch manager to pending page", %{conn: conn} do
    post(conn, ~p"/login", otp: %{phone: "09120000000"})

    conn =
      build_conn()
      |> post(~p"/verify", otp: %{phone: "09120000000", code: "123456"})

    assert get_session(conn, :user_phone) == "09120000000"
    assert get_session(conn, :user_role) == "branch_manager_pending"
    assert redirected_to(conn) == ~p"/manager/pending"
  end

  test "confirming OTP logs approved branch manager in and redirects to manager panel", %{
    conn: conn
  } do
    branch_fixture(%{manager_phone: "09120000000"})
    post(conn, ~p"/login", otp: %{phone: "09120000000"})

    conn =
      build_conn()
      |> post(~p"/verify", otp: %{phone: "09120000000", code: "123456"})

    assert get_session(conn, :user_phone) == "09120000000"
    assert get_session(conn, :user_role) == "branch_manager"
    assert redirected_to(conn) == ~p"/manager"
  end

  test "admin routes redirect anonymous users to login", %{conn: conn} do
    conn = get(conn, ~p"/admin/reports")
    assert redirected_to(conn) == ~p"/login"
  end

  test "admin routes allow logged-in admin", %{conn: conn} do
    conn =
      conn
      |> log_in_admin()
      |> get(~p"/admin/reports")

    assert html_response(conn, 200) =~ "گزارش ادمین"
  end

  test "manager routes require login and pending managers see pending page", %{conn: conn} do
    conn = get(conn, ~p"/manager")
    assert redirected_to(conn) == ~p"/login"

    conn =
      build_conn()
      |> log_in_branch_manager()
      |> get(~p"/manager")

    assert redirected_to(conn) == ~p"/manager/pending"
  end
end
