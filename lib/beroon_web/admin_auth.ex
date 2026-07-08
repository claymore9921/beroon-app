defmodule BeroonWeb.AdminAuth do
  import Plug.Conn
  import Phoenix.Controller

  alias Beroon.Auth
  alias Beroon.Operations

  use BeroonWeb, :verified_routes

  def init(action), do: action

  def call(conn, :fetch_current_user) do
    phone = get_session(conn, :user_phone) || get_session(conn, :admin_phone)
    role = get_session(conn, :user_role)

    if phone do
      normalized_phone = Auth.normalize_phone(phone)
      resolved_role = role || Atom.to_string(Auth.role_for_phone(normalized_phone))

      conn
      |> assign(:current_user_phone, normalized_phone)
      |> assign(:current_user_role, resolved_role)
      |> assign(:current_admin_phone, resolved_role == "admin" && normalized_phone)
      |> assign(:current_branch_name, current_branch_name(resolved_role, normalized_phone))
      |> assign(:current_branch_id, current_branch_id(resolved_role, normalized_phone))
    else
      conn
      |> assign(:current_user_phone, nil)
      |> assign(:current_user_role, nil)
      |> assign(:current_admin_phone, nil)
      |> assign(:current_branch_name, nil)
      |> assign(:current_branch_id, nil)
    end
  end

  def call(conn, :fetch_current_admin), do: call(conn, :fetch_current_user)

  def call(conn, :require_authenticated) do
    if conn.assigns[:current_user_phone] do
      conn
    else
      conn
      |> put_session(:user_return_to, current_path(conn))
      |> put_flash(:error, "برای ادامه وارد شوید.")
      |> redirect(to: ~p"/login")
      |> halt()
    end
  end

  def call(conn, :require_admin) do
    if conn.assigns[:current_user_role] == "admin" do
      conn
    else
      conn
      |> put_session(:user_return_to, current_path(conn))
      |> put_flash(:error, "برای دسترسی ادمین وارد شوید.")
      |> redirect(to: ~p"/login")
      |> halt()
    end
  end

  def log_in_user(conn, %{phone: phone, role: role}) do
    conn
    |> configure_session(renew: true)
    |> put_session(:user_phone, Auth.normalize_phone(phone))
    |> put_session(:user_role, Atom.to_string(role))
  end

  def log_in_admin(conn, phone), do: log_in_user(conn, %{phone: phone, role: :admin})

  def log_out_user(conn), do: configure_session(conn, drop: true)
  def log_out_admin(conn), do: log_out_user(conn)

  defp current_branch_name("branch_manager", phone) do
    case Operations.get_branch_for_manager_phone(phone) do
      nil -> nil
      branch -> branch.name
    end
  end

  defp current_branch_name("workshop_manager", phone) do
    case Operations.get_workshop_for_manager_phone(phone) do
      nil -> nil
      workshop -> workshop.name
    end
  end

  defp current_branch_name(_role, _phone), do: nil

  defp current_branch_id("branch_manager", phone) do
    case Operations.get_branch_for_manager_phone(phone) do
      nil -> nil
      branch -> branch.id
    end
  end

  defp current_branch_id("workshop_manager", phone) do
    case Operations.get_workshop_for_manager_phone(phone) do
      nil -> nil
      workshop -> workshop.id
    end
  end

  defp current_branch_id(_role, _phone), do: nil
end
