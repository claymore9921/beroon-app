defmodule Beroon.LocationHistory do
  import Ecto.Query, warn: false

  alias Beroon.LocationHistory.LocationEvent
  alias Beroon.Operations.Branch
  alias Beroon.Repo

  def record(scooter_id, branch_id),
    do: record(scooter_id, branch_id, DateTime.utc_now() |> DateTime.truncate(:second))

  def record(_scooter_id, nil, _observed_at), do: :ok

  def record(scooter_id, branch_id, observed_at) do
    attrs = %{scooter_id: scooter_id, branch_id: branch_id, observed_at: observed_at}

    case %LocationEvent{} |> LocationEvent.changeset(attrs) |> Repo.insert() do
      {:ok, _event} -> :ok
      {:error, _changeset} -> :error
    end
  end

  def list_recent(scooter_id, limit \\ 10) do
    LocationEvent
    |> where([e], e.scooter_id == ^scooter_id)
    |> join(:left, [e], b in Branch, on: b.id == e.branch_id)
    |> order_by([e], desc: e.observed_at, desc: e.id)
    |> limit(^limit)
    |> preload([e, b], branch: b)
    |> Repo.all()
  end
end
