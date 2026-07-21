defmodule Beroon.Logistics do
  import Ecto.Query, warn: false

  alias Beroon.Fleet.Scooter
  alias Beroon.Logistics.ScooterTransport
  alias Beroon.Operations.Branch
  alias Beroon.Repo

  def register_transport(scooter, destination_branch, manager_branch, actor, notes \\ "") do
    scooter = Repo.preload(scooter, [:current_branch, :branch])
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    cond do
      is_nil(scooter.current_branch_id) ->
        {:error, :current_branch_missing}

      scooter.current_branch_id == destination_branch.id ->
        {:error, :same_branch}

      scooter.branch_id != manager_branch.id ->
        {:error, :not_owned_by_manager_branch}

      true ->
        Repo.transaction(fn ->
          attrs = %{
            scooter_id: scooter.id,
            origin_branch_id: scooter.current_branch_id,
            destination_branch_id: destination_branch.id,
            registered_by_branch_id: manager_branch.id,
            registered_by_phone: actor.phone,
            registered_by_name: actor.name,
            transported_at: now,
            notes: String.trim(to_string(notes || ""))
          }

          case %ScooterTransport{} |> ScooterTransport.changeset(attrs) |> Repo.insert() do
            {:ok, transport} ->
              scooter
              |> Ecto.Changeset.change(current_branch_id: destination_branch.id)
              |> Repo.update!()

              transport

            {:error, changeset} ->
              Repo.rollback(changeset)
          end
        end)
    end
  end

  def list_transports_for_branch(branch_id, limit \\ 30) do
    ScooterTransport
    |> where(
      [t],
      t.registered_by_branch_id == ^branch_id or t.origin_branch_id == ^branch_id or
        t.destination_branch_id == ^branch_id
    )
    |> order_by([t], desc: t.transported_at)
    |> limit(^limit)
    |> preload([:scooter, :origin_branch, :destination_branch, :registered_by_branch])
    |> Repo.all()
  end

  def list_recent_transports(limit \\ 50) do
    ScooterTransport
    |> order_by([t], desc: t.transported_at)
    |> limit(^limit)
    |> preload([:scooter, :origin_branch, :destination_branch, :registered_by_branch])
    |> Repo.all()
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
      |> Repo.one()
      |> case do
        nil -> nil
        scooter -> %{scooter: scooter, transports: list_transports_for_scooter(scooter.id)}
      end
    end
  end

  defp list_transports_for_scooter(scooter_id) do
    ScooterTransport
    |> where([t], t.scooter_id == ^scooter_id)
    |> order_by([t], desc: t.transported_at)
    |> limit(15)
    |> preload([:origin_branch, :destination_branch, :registered_by_branch])
    |> Repo.all()
  end
end
