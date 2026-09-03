defmodule Beroon.Logistics do
  import Ecto.Query, warn: false

  alias Beroon.Fleet.Scooter
  alias Beroon.Operations.Branch
  alias Beroon.Repo

  # ثبت مشاهده فیزیکی دستگاه در یک شعبه. در آمار شب هر دستگاه مجاز که دیده
  # می‌شود فعال شده و current_branch_id آن به شعبه اسکن‌کننده تغییر می‌کند.
  # اگر شعبه اسکن‌کننده با مالک دستگاه (branch_id) فرق داشته باشد، دستگاه از
  # دید مالک «جابجا شده» محسوب می‌شود؛ نیازی به ثبت جداگانه‌ای برای این جابجایی
  # نیست، چون خود رکورد آمار شب همین موضوع را مستند می‌کند.
  def mark_evening_seen(%Scooter{} = scooter, branch_id) do
    updated =
      scooter
      |> Ecto.Changeset.change(status: "active", current_branch_id: branch_id)
      |> Repo.update!()

    Beroon.LocationHistory.record(updated.id, branch_id)
    updated
  end

  def mark_evening_seen(%{id: id} = scooter, branch_id) do
    updated =
      Repo.get!(Scooter, id)
      |> Ecto.Changeset.change(status: "active", current_branch_id: branch_id)
      |> Repo.update!()

    Beroon.LocationHistory.record(updated.id, branch_id)

    scooter
    |> Map.put(:status, "active")
    |> Map.put(:current_branch_id, branch_id)
  end

  # برای چک‌لیست صبح فقط محل مشاهده به‌روزرسانی می‌شود؛ وضعیت عملیاتی دستگاه
  # بدون دلیل تغییر نمی‌کند.
  def mark_seen_at_branch(%Scooter{} = scooter, branch_id) do
    updated =
      scooter
      |> Ecto.Changeset.change(current_branch_id: branch_id)
      |> Repo.update!()

    Beroon.LocationHistory.record(updated.id, branch_id)
    updated
  end

  def mark_seen_at_branch(%{id: id} = scooter, branch_id) do
    updated =
      Repo.get!(Scooter, id)
      |> Ecto.Changeset.change(current_branch_id: branch_id)
      |> Repo.update!()

    Beroon.LocationHistory.record(updated.id, branch_id)
    Map.put(scooter, :current_branch_id, branch_id)
  end

  def find_scooter_location(code) do
    clean_code = code |> to_string() |> String.trim()

    if clean_code == "" do
      nil
    else
      pattern = "%#{clean_code}%"

      Scooter
      |> join(:left, [s], owner in Branch, on: owner.id == s.branch_id)
      |> join(:left, [s, owner], current in Branch, on: current.id == s.current_branch_id)
      |> where(
        [s, owner, current],
        s.plate == ^clean_code or s.barcode == ^clean_code or ilike(s.plate, ^pattern) or
          ilike(s.barcode, ^pattern)
      )
      |> order_by([s], asc: s.plate)
      |> limit(1)
      |> preload([s, owner, current], branch: owner, current_branch: current)
      |> preload(:device_type)
      |> Repo.one()
      |> case do
        nil -> nil
        scooter -> %{scooter: scooter}
      end
    end
  end

  alias Beroon.Logistics.ScooterLoan

  def list_open_loans do
    ScooterLoan
    |> where([l], is_nil(l.returned_at))
    |> order_by([l], desc: l.loaned_at)
    |> preload([scooter: [:branch, :device_type]])
    |> Repo.all()
  end

  def loan_scooter(scooter, attrs) do
    Repo.transaction(fn ->
      loan_attrs = Map.merge(%{
        scooter_id: scooter.id,
        previous_status: scooter.status,
        loaned_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }, attrs)

      loan = case %ScooterLoan{} |> ScooterLoan.changeset(loan_attrs) |> Repo.insert() do
        {:ok, loan} -> loan
        {:error, changeset} -> Repo.rollback(changeset)
      end

      case Beroon.Fleet.update_scooter(scooter, %{status: "loaned"}) do
        {:ok, _} -> loan
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  def return_loan(%ScooterLoan{} = loan) do
    Repo.transaction(fn ->
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      case loan |> ScooterLoan.changeset(%{returned_at: now}) |> Repo.update() do
        {:ok, updated} ->
          scooter = Beroon.Fleet.get_scooter!(loan.scooter_id)
          case Beroon.Fleet.update_scooter(scooter, %{status: loan.previous_status || "active"}) do
            {:ok, _} -> updated
            {:error, changeset} -> Repo.rollback(changeset)
          end
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end
end
