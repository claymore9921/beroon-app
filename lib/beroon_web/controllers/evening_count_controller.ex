defmodule BeroonWeb.EveningCountController do
  use BeroonWeb, :controller

  alias Beroon.Reports
  alias Beroon.Reports.EveningCount

  def index(conn, _params) do
    evening_counts = Reports.list_evening_counts()
    render(conn, :index, evening_counts: evening_counts)
  end

  def new(conn, _params) do
    changeset = Reports.change_evening_count(%EveningCount{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"evening_count" => evening_count_params}) do
    case Reports.create_evening_count(evening_count_params) do
      {:ok, evening_count} ->
        conn
        |> put_flash(:info, "Evening count created successfully.")
        |> redirect(to: ~p"/evening_counts/#{evening_count}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    evening_count = Reports.get_evening_count!(id)
    render(conn, :show, evening_count: evening_count)
  end

  def edit(conn, %{"id" => id}) do
    evening_count = Reports.get_evening_count!(id)
    changeset = Reports.change_evening_count(evening_count)
    render(conn, :edit, evening_count: evening_count, changeset: changeset)
  end

  def update(conn, %{"id" => id, "evening_count" => evening_count_params}) do
    evening_count = Reports.get_evening_count!(id)

    case Reports.update_evening_count(evening_count, evening_count_params) do
      {:ok, evening_count} ->
        conn
        |> put_flash(:info, "Evening count updated successfully.")
        |> redirect(to: ~p"/evening_counts/#{evening_count}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, evening_count: evening_count, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    evening_count = Reports.get_evening_count!(id)
    {:ok, _evening_count} = Reports.delete_evening_count(evening_count)

    conn
    |> put_flash(:info, "Evening count deleted successfully.")
    |> redirect(to: ~p"/evening_counts")
  end
end
