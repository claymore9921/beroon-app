defmodule BeroonWeb.AdminSessionController do
  use BeroonWeb, :controller

  alias Beroon.Auth
  alias BeroonWeb.AdminAuth

  def new(conn, _params) do
    render(conn, :new, phone: "")
  end

  def create(conn, %{"otp" => %{"phone" => phone}}) do
    case Auth.request_login_otp(phone) do
      {:ok, _challenge} ->
        conn
        |> put_flash(:info, "کد ورود در کنسول سرور چاپ شد.")
        |> redirect(to: ~p"/verify?phone=#{Auth.normalize_phone(phone)}")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "کد ورود ساخته نشد. دوباره تلاش کنید.")
        |> render(:new, phone: phone)
    end
  end

  def verify(conn, params) do
    render(conn, :verify, phone: Auth.normalize_phone(params["phone"]))
  end

  def confirm(conn, %{"otp" => %{"phone" => phone, "code" => code}}) do
    case Auth.verify_login_otp(phone, code) do
      {:ok, user} ->
        return_to = get_session(conn, :user_return_to) || role_home_path(user.role)

        conn
        |> AdminAuth.log_in_user(user)
        |> delete_session(:user_return_to)
        |> put_flash(:info, "ورود انجام شد.")
        |> redirect(to: return_to)

      {:error, :too_many_attempts} ->
        conn
        |> put_flash(:error, "تعداد تلاش‌ها زیاد شد. دوباره کد بگیرید.")
        |> redirect(to: ~p"/login")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "کد ورود نامعتبر یا منقضی است.")
        |> render(:verify, phone: Auth.normalize_phone(phone))
    end
  end

  def delete(conn, _params) do
    conn
    |> AdminAuth.log_out_user()
    |> redirect(to: ~p"/login")
  end

  defp role_home_path(:admin), do: ~p"/admin/reports"
  defp role_home_path(:branch_manager), do: ~p"/manager"
  defp role_home_path(:branch_manager_pending), do: ~p"/manager/pending"
end
