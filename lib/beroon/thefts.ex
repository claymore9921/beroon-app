defmodule Beroon.Thefts do
  import Ecto.Query, warn: false

  alias Beroon.Fleet
  alias Beroon.Fleet.Scooter
  alias Beroon.Repo
  alias Beroon.Thefts.StolenDevice

  def list_open_stolen_devices do
    StolenDevice
    |> where([record], is_nil(record.recovered_at))
    |> order_by([record], desc: record.reported_at)
    |> preload([:branch, :device_type])
    |> preload(scooter: [:branch, :device_type])
    |> Repo.all()
  end

  def get_stolen_device!(id) do
    StolenDevice
    |> preload([:branch, :device_type])
    |> preload(scooter: [:branch, :device_type])
    |> Repo.get!(id)
  end

  def register_plated_scooter(%Scooter{} = scooter, branch_id, attrs \\ %{}) do
    scooter = Repo.preload(scooter, [:branch, :device_type])
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    cond do
      scooter.status == "stolen" ->
        {:error, :already_stolen}

      is_nil(scooter.device_type_id) ->
        {:error, :device_type_missing}

      true ->
        Repo.transaction(fn ->
          record_attrs = %{
            scooter_id: scooter.id,
            branch_id: branch_id,
            device_type_id: scooter.device_type_id,
            quantity: 1,
            plate_snapshot: scooter.plate,
            previous_status: if(scooter.status == "transport", do: "active", else: scooter.status),
            reported_at: now,
            registered_by_phone: attrs[:registered_by_phone] || attrs["registered_by_phone"],
            notes: attrs[:notes] || attrs["notes"]
          }

          record =
            case %StolenDevice{} |> StolenDevice.changeset(record_attrs) |> Repo.insert() do
              {:ok, record} -> record
              {:error, changeset} -> Repo.rollback(changeset)
            end

          case Fleet.update_scooter(scooter, %{status: "stolen", transport_until: nil}) do
            {:ok, _scooter} -> record
            {:error, changeset} -> Repo.rollback(changeset)
          end
        end)
    end
  end

  def register_unplated_devices(attrs) do
    normalized = %{
      branch_id: attrs[:branch_id] || attrs["branch_id"],
      device_type_id: attrs[:device_type_id] || attrs["device_type_id"],
      quantity: attrs[:quantity] || attrs["quantity"],
      reported_at: DateTime.utc_now() |> DateTime.truncate(:second),
      registered_by_phone: attrs[:registered_by_phone] || attrs["registered_by_phone"],
      notes: attrs[:notes] || attrs["notes"]
    }

    %StolenDevice{}
    |> StolenDevice.changeset(normalized)
    |> Repo.insert()
  end

  def recover(%StolenDevice{} = record) do
    Repo.transaction(fn ->
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      updated =
        case record |> StolenDevice.changeset(%{recovered_at: now}) |> Repo.update() do
          {:ok, updated} -> updated
          {:error, changeset} -> Repo.rollback(changeset)
        end

      if record.scooter_id do
        scooter = Fleet.get_scooter!(record.scooter_id)

        case Fleet.update_scooter(scooter, %{status: record.previous_status || "active"}) do
          {:ok, _scooter} -> :ok
          {:error, changeset} -> Repo.rollback(changeset)
        end
      end

      updated
    end)
  end

  def open_counts_by_device_type do
    StolenDevice
    |> where([record], is_nil(record.recovered_at))
    |> group_by([record], record.device_type_id)
    |> select([record], {record.device_type_id, sum(record.quantity)})
    |> Repo.all()
    |> Map.new()
  end

  def open_breakdown do
    StolenDevice
    |> where([record], is_nil(record.recovered_at))
    |> join(:inner, [record], branch in assoc(record, :branch))
    |> join(:inner, [record, branch], device_type in assoc(record, :device_type))
    |> group_by([record, branch, device_type], [
      branch.id,
      branch.name,
      device_type.id,
      device_type.device_identifier,
      device_type.category,
      device_type.device_model
    ])
    |> order_by([record, branch, device_type], asc: branch.name, asc: device_type.category, asc: device_type.device_model)
    |> select([record, branch, device_type], %{
      branch_id: branch.id,
      branch_name: branch.name,
      device_type_id: device_type.id,
      device_identifier: device_type.device_identifier,
      category: device_type.category,
      device_model: device_type.device_model,
      quantity: sum(record.quantity)
    })
    |> Repo.all()
  end
end
