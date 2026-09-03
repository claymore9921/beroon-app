defmodule BeroonWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use BeroonWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint BeroonWeb.Endpoint

      use BeroonWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import BeroonWeb.ConnCase
    end
  end

  setup tags do
    Beroon.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  def log_in_admin(conn) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_phone, Beroon.Auth.admin_phone())
    |> Plug.Conn.put_session(:user_role, "admin")
  end

  def log_in_branch_manager(conn, phone \\ "09120000000") do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_phone, phone)
    |> Plug.Conn.put_session(:user_role, "branch_manager")
  end

  def log_in_workshop_manager(conn, phone \\ "09130000000") do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_phone, phone)
    |> Plug.Conn.put_session(:user_role, "workshop_manager")
  end
end
