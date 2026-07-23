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
              |> Ecto.Changeset.change(
                current_branch_id: destination_branch.id,
                status: "transport",
                transport_until: DateTime.add(now, 16 * 60 * 60, :second)
              )
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

  def expire_transports! do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Scooter
    |> where([s], s.status == "transport" and not is_nil(s.transport_until) and s.transport_until <= ^now)
    |> Repo.update_all(set: [status: "active", transport_until: nil, updated_at: now])
  end

  def refresh_expired_transport(%Scooter{status: "transport", transport_until: until_at} = scooter)
      when not is_nil(until_at) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    if DateTime.compare(until_at, now) in [:lt, :eq] do
      scooter
      |> Ecto.Changeset.change(status: "active", transport_until: nil)
      |> Repo.update!()
    else
      scooter
    end
  end

  def refresh_expired_transport(%Scooter{} = scooter), do: scooter

  def refresh_expired_transport(%{id: id, status: "transport", transport_until: until_at} = scooter)
      when not is_nil(until_at) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    if DateTime.compare(until_at, now) in [:lt, :eq] do
      Repo.get!(Scooter, id)
      |> Ecto.Changeset.change(status: "active", transport_until: nil)
      |> Repo.update!()

      scooter |> Map.put(:status, "active") |> Map.put(:transport_until, nil)
    else
      scooter
    end
  end

  def refresh_expired_transport(%{} = scooter), do: scooter

  def activate_owner_return(%Scooter{} = scooter, owner_branch_id) do
    if scooter.status == "transport" and scooter.branch_id == owner_branch_id do
      scooter
      |> Ecto.Changeset.change(status: "active", transport_until: nil, current_branch_id: owner_branch_id)
      |> Repo.update!()
    else
      scooter
    end
  end

  def activate_owner_return(%{id: id, status: "transport", branch_id: owner_branch_id} = scooter, owner_branch_id) do
    Repo.get!(Scooter, id)
    |> Ecto.Changeset.change(status: "active", transport_until: nil, current_branch_id: owner_branch_id)
    |> Repo.update!()

    scooter
    |> Map.put(:status, "active")
    |> Map.put(:transport_until, nil)
    |> Map.put(:current_branch_id, owner_branch_id)
  end

  def activate_owner_return(%{} = scooter, _owner_branch_id), do: scooter

  def list_active_transports_for_branch(branch_id) do
    expire_transports!()
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Scooter
    |> where([s], s.status == "transport" and s.transport_until > ^now)
    |> where([s], s.branch_id == ^branch_id or s.current_branch_id == ^branch_id)
    |> preload([:branch, :current_branch, :device_type])
    |> order_by([s], asc: s.plate)
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
