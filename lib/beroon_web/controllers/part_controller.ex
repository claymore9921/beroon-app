defmodule BeroonWeb.PartController do
  use BeroonWeb, :controller

  alias Beroon.Parts
  alias Beroon.Parts.Part

  def index(conn, _params) do
    render(conn, :index, parts: Parts.list_parts(), form: Phoenix.Component.to_form(Parts.change_part(%Part{})))
  end

  def create(conn, %{"part" => params}) do
    case Parts.create_part(params) do
      {:ok, _part} ->
        conn
        |> put_flash(:info, "قطعه جدید ثبت شد.")
        |> redirect(to: ~p"/admin/parts")

      {:error, changeset} ->
        conn
        |> put_flash(:error, "ثبت قطعه انجام نشد: بررسی کنید نام تکراری نباشد و تعداد معتبر باشد.")
        |> render(:index, parts: Parts.list_parts(), form: Phoenix.Component.to_form(changeset))
    end
  end

  def update(conn, %{"id" => id, "part" => params}) do
    part = Parts.get_part!(id)

    case Parts.update_part(part, params) do
      {:ok, _part} ->
        conn
        |> put_flash(:info, "قطعه ویرایش شد.")
        |> redirect(to: ~p"/admin/parts")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "ویرایش قطعه انجام نشد.")
        |> redirect(to: ~p"/admin/parts")
    end
  end

  def delete(conn, %{"id" => id}) do
    part = Parts.get_part!(id)
    {:ok, _part} = Parts.delete_part(part)

    conn
    |> put_flash(:info, "قطعه حذف شد.")
    |> redirect(to: ~p"/admin/parts")
  end
end
