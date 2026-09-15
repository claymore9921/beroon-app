defmodule BeroonWeb.ConsumableController do
  use BeroonWeb, :controller

  alias Beroon.Consumables
  alias Beroon.Consumables.Consumable

  def index(conn, _params) do
    render(conn, :index,
      consumables: Consumables.list_consumables(),
      form: Phoenix.Component.to_form(Consumables.change_consumable(%Consumable{}))
    )
  end

  def create(conn, %{"consumable" => params}) do
    case Consumables.create_consumable(params) do
      {:ok, _consumable} ->
        conn
        |> put_flash(:info, "کالای مصرفی جدید ثبت شد.")
        |> redirect(to: ~p"/admin/consumables")

      {:error, changeset} ->
        conn
        |> put_flash(:error, "ثبت کالا انجام نشد: بررسی کنید نام تکراری نباشد و تعداد معتبر باشد.")
        |> render(:index, consumables: Consumables.list_consumables(), form: Phoenix.Component.to_form(changeset))
    end
  end

  def update(conn, %{"id" => id, "consumable" => params}) do
    consumable = Consumables.get_consumable!(id)

    case Consumables.update_consumable(consumable, params) do
      {:ok, _consumable} ->
        conn
        |> put_flash(:info, "کالای مصرفی ویرایش شد.")
        |> redirect(to: ~p"/admin/consumables")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "ویرایش انجام نشد.")
        |> redirect(to: ~p"/admin/consumables")
    end
  end

  def delete(conn, %{"id" => id}) do
    consumable = Consumables.get_consumable!(id)
    {:ok, _consumable} = Consumables.delete_consumable(consumable)

    conn
    |> put_flash(:info, "کالای مصرفی حذف شد.")
    |> redirect(to: ~p"/admin/consumables")
  end
end
