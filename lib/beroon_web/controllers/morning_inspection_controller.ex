defmodule BeroonWeb.MorningInspectionController do
  use BeroonWeb, :controller

  alias Beroon.Reports
  alias Beroon.Reports.MorningInspection

  def index(conn, _params) do
    morning_inspections = Reports.list_morning_inspections()
    render(conn, :index, morning_inspections: morning_inspections)
  end

  def new(conn, _params) do
    changeset = Reports.change_morning_inspection(%MorningInspection{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"morning_inspection" => morning_inspection_params}) do
    case Reports.create_morning_inspection(morning_inspection_params) do
      {:ok, morning_inspection} ->
        conn
        |> put_flash(:info, "Morning inspection created successfully.")
        |> redirect(to: ~p"/morning_inspections/#{morning_inspection}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    morning_inspection = Reports.get_morning_inspection!(id)
    render(conn, :show, morning_inspection: morning_inspection)
  end

  def edit(conn, %{"id" => id}) do
    morning_inspection = Reports.get_morning_inspection!(id)
    changeset = Reports.change_morning_inspection(morning_inspection)
    render(conn, :edit, morning_inspection: morning_inspection, changeset: changeset)
  end

  def update(conn, %{"id" => id, "morning_inspection" => morning_inspection_params}) do
    morning_inspection = Reports.get_morning_inspection!(id)

    case Reports.update_morning_inspection(morning_inspection, morning_inspection_params) do
      {:ok, morning_inspection} ->
        conn
        |> put_flash(:info, "Morning inspection updated successfully.")
        |> redirect(to: ~p"/morning_inspections/#{morning_inspection}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, morning_inspection: morning_inspection, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    morning_inspection = Reports.get_morning_inspection!(id)
    {:ok, _morning_inspection} = Reports.delete_morning_inspection(morning_inspection)

    conn
    |> put_flash(:info, "Morning inspection deleted successfully.")
    |> redirect(to: ~p"/morning_inspections")
  end
end
