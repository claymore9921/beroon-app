defmodule BeroonWeb.ChecklistItemController do
  use BeroonWeb, :controller

  alias Beroon.Checklists
  alias Beroon.Checklists.ChecklistItem

  def index(conn, _params) do
    checklist_items = Checklists.list_checklist_items()
    render(conn, :index, checklist_items: checklist_items)
  end

  def new(conn, _params) do
    changeset = Checklists.change_checklist_item(%ChecklistItem{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"checklist_item" => checklist_item_params}) do
    case Checklists.create_checklist_item(checklist_item_params) do
      {:ok, checklist_item} ->
        conn
        |> put_flash(:info, "آیتم چک‌لیست ثبت شد.")
        |> redirect(to: ~p"/checklist_items/#{checklist_item}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    checklist_item = Checklists.get_checklist_item!(id)
    render(conn, :show, checklist_item: checklist_item)
  end

  def edit(conn, %{"id" => id}) do
    checklist_item = Checklists.get_checklist_item!(id)
    changeset = Checklists.change_checklist_item(checklist_item)
    render(conn, :edit, checklist_item: checklist_item, changeset: changeset)
  end

  def update(conn, %{"id" => id, "checklist_item" => checklist_item_params}) do
    checklist_item = Checklists.get_checklist_item!(id)

    case Checklists.update_checklist_item(checklist_item, checklist_item_params) do
      {:ok, checklist_item} ->
        conn
        |> put_flash(:info, "آیتم چک‌لیست ویرایش شد.")
        |> redirect(to: ~p"/checklist_items/#{checklist_item}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, checklist_item: checklist_item, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    checklist_item = Checklists.get_checklist_item!(id)
    {:ok, _checklist_item} = Checklists.delete_checklist_item(checklist_item)

    conn
    |> put_flash(:info, "آیتم چک‌لیست حذف شد.")
    |> redirect(to: ~p"/checklist_items")
  end
end
