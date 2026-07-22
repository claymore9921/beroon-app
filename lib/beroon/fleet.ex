defmodule Beroon.Fleet do
  @moduledoc """
  The Fleet context.
  """

  import Ecto.Query, warn: false
  alias Beroon.Repo

  alias Beroon.Fleet.Scooter
  alias Beroon.Fleet.DeviceType
  alias Beroon.Operations.Branch

  def list_device_types do
    DeviceType
    |> order_by([d], asc: d.device_identifier)
    |> Repo.all()
  end

  def list_active_device_types do
    DeviceType
    |> where([d], d.active == true)
    |> order_by([d], asc: d.device_identifier)
    |> Repo.all()
  end

  def get_device_type!(id), do: Repo.get!(DeviceType, id)

  def create_device_type(attrs) do
    %DeviceType{}
    |> DeviceType.changeset(attrs)
    |> Repo.insert()
  end

  def update_device_type(%DeviceType{} = device_type, attrs) do
    device_type
    |> DeviceType.changeset(attrs)
    |> Repo.update()
  end

  def delete_device_type(%DeviceType{} = device_type), do: Repo.delete(device_type)

  def change_device_type(%DeviceType{} = device_type, attrs \\ %{}) do
    DeviceType.changeset(device_type, attrs)
  end

  @doc """
  Returns the list of scooters.

  ## Examples

      iex> list_scooters()
      [%Scooter{}, ...]

  """
  def list_scooters do
    Scooter
    |> order_by([s], asc: s.plate)
    |> Repo.all()
  end

  def list_scooters_with_details(search_term \\ nil) do
    search_term = search_term |> to_string() |> String.trim()

    Scooter
    |> join(:left, [s], b in Branch, on: b.id == s.branch_id)
    |> join(:left, [s, b], d in DeviceType, on: d.id == s.device_type_id)
    |> maybe_filter_scooters(search_term)
    |> order_by([s, b, d], asc: s.plate)
    |> preload([s, b, d], branch: b, device_type: d)
    |> Repo.all()
  end

  defp maybe_filter_scooters(query, ""), do: query

  defp maybe_filter_scooters(query, search_term) do
    pattern = "%#{search_term}%"
    statuses = matching_status_values(search_term)

    where(
      query,
      [s, b, d],
      ilike(s.barcode, ^pattern) or
        ilike(s.plate, ^pattern) or
        ilike(s.model, ^pattern) or
        ilike(s.status, ^pattern) or
        ilike(s.notes, ^pattern) or
        ilike(b.name, ^pattern) or
        ilike(b.code, ^pattern) or
        ilike(b.manager_name, ^pattern) or
        ilike(d.device_identifier, ^pattern) or
        ilike(d.category, ^pattern) or
        ilike(d.device_model, ^pattern) or
        ilike(d.name, ^pattern) or
        ilike(d.code, ^pattern) or
        fragment("CAST(? AS TEXT) ILIKE ?", s.id, ^pattern) or
        s.status in ^statuses
    )
  end

  defp matching_status_values(search_term) do
    normalized = String.downcase(search_term)

    [
      {"active", "فعال"},
      {"needs_service", "خراب"},
      {"awaiting_repair", "در انتظار تعمیر"},
      {"repairing", "در حال تعمیر"},
      {"waiting_for_part", "در انتظار قطعه"},
      {"ready_for_pickup", "آماده تحویل"},
      {"out_of_service", "از مدار خارج شده"}
    ]
    |> Enum.filter(fn {value, label} ->
      String.contains?(value, normalized) or String.contains?(String.downcase(label), normalized)
    end)
    |> Enum.map(&elem(&1, 0))
  end


  def expected_evening_scooters_for_branch(branch_id) do
    Scooter
    |> where(
      [s],
      s.branch_id == ^branch_id and s.current_branch_id == ^branch_id and
        s.status not in ["awaiting_repair", "repairing", "waiting_for_part", "ready_for_pickup", "out_of_service"]
    )
    |> order_by([s], asc: s.plate)
    |> Repo.all()
  end

  def branch_inventory_groups(branch_id) do
    Scooter
    |> where([s], s.branch_id == ^branch_id)
    |> join(:left, [s], d in DeviceType, on: d.id == s.device_type_id)
    |> order_by([s, d], asc: d.category, asc: d.device_model, asc: s.plate)
    |> preload([s, d], device_type: d)
    |> Repo.all()
    |> Enum.group_by(fn scooter ->
      case scooter.device_type do
        nil -> "بدون نوع دستگاه"
        d -> Enum.reject([d.device_identifier, d.category, d.device_model], &(&1 in [nil, ""])) |> Enum.join(" - ")
      end
    end)
    |> Enum.map(fn {label, scooters} -> %{label: label, count: length(scooters), scooters: scooters} end)
    |> Enum.sort_by(& &1.label)
  end

  def list_scooters_for_branch(branch_id) do
    Scooter
    |> where([s], s.branch_id == ^branch_id)
    |> order_by([s], asc: s.plate)
    |> Repo.all()
  end

  def list_scooters_for_branch_with_details(branch_id, status \\ nil)

  def list_scooters_for_branch_with_details(nil, _status), do: []

  def list_scooters_for_branch_with_details(branch_id, status) do
    Scooter
    |> where([s], s.branch_id == ^branch_id)
    |> maybe_filter_status(status)
    |> order_by([s], asc: s.plate)
    |> preload([:branch, :device_type])
    |> Repo.all()
  end

  def list_scooters_for_branch_by_statuses(branch_id, statuses)

  def list_scooters_for_branch_by_statuses(nil, _statuses), do: []

  def list_scooters_for_branch_by_statuses(branch_id, statuses) do
    Scooter
    |> where([s], s.branch_id == ^branch_id)
    |> where([s], s.status in ^List.wrap(statuses))
    |> order_by([s], asc: s.plate)
    |> preload([:branch, :device_type])
    |> Repo.all()
  end

  def list_scooters_for_branch_search(branch_id, search_term \\ nil, status \\ nil)

  def list_scooters_for_branch_search(nil, _search_term, _status), do: []

  def list_scooters_for_branch_search(branch_id, search_term, status) do
    search_term = search_term |> to_string() |> String.trim()
    pattern = "%#{search_term}%"

    Scooter
    |> where([s], s.branch_id == ^branch_id)
    |> maybe_filter_status(status)
    |> then(fn query ->
      if search_term == "" do
        query
      else
        where(query, [s], ilike(s.plate, ^pattern) or ilike(s.barcode, ^pattern))
      end
    end)
    |> order_by([s], asc: s.plate)
    |> preload([:branch, :device_type])
    |> Repo.all()
  end

  def list_scooters_by_statuses(statuses) do
    list_scooters_by_statuses(statuses, nil)
  end

  def list_scooters_by_statuses(statuses, search_term) do
    search_term = search_term |> to_string() |> String.trim()
    pattern = "%#{search_term}%"

    Scooter
    |> where([s], s.status in ^List.wrap(statuses))
    |> then(fn query ->
      if search_term == "" do
        query
      else
        where(query, [s], ilike(s.plate, ^pattern) or ilike(s.barcode, ^pattern))
      end
    end)
    |> order_by([s], asc: s.plate)
    |> preload([:branch, :device_type])
    |> Repo.all()
  end

  defp maybe_filter_status(query, status)
       when status in [
              "active",
              "needs_service",
              "awaiting_repair",
              "repairing",
              "waiting_for_part",
              "ready_for_pickup",
              "out_of_service"
            ] do
    where(query, [s], s.status == ^status)
  end

  defp maybe_filter_status(query, _status), do: query

  def count_scooters_for_branch(branch_id) do
    Scooter
    |> where([s], s.branch_id == ^branch_id)
    |> Repo.aggregate(:count, :id)
  end

  def count_scooters_for_branch_by_status(branch_id) do
    Scooter
    |> where([s], s.branch_id == ^branch_id)
    |> group_by([s], s.status)
    |> select([s], {s.status, count(s.id)})
    |> Repo.all()
    |> Map.new()
  end

  def count_scooters_by_status do
    Scooter
    |> group_by([s], s.status)
    |> select([s], {s.status, count(s.id)})
    |> Repo.all()
    |> Map.new()
  end

  def get_scooter_by_barcode(branch_id, barcode) when is_binary(barcode) do
    clean_barcode = String.trim(barcode)

    Scooter
    |> where([s], s.branch_id == ^branch_id and s.barcode == ^clean_barcode)
    |> Repo.one()
  end

  def get_scooter_by_plate_or_barcode(code) when is_binary(code) do
    codes = lookup_codes(code)

    Scooter
    |> join(:left, [s], b in Beroon.Operations.Branch, on: b.id == s.branch_id)
    |> join(:left, [s, b], c in Beroon.Operations.Branch, on: c.id == s.current_branch_id)
    |> join(:left, [s, b, c], d in DeviceType, on: d.id == s.device_type_id)
    |> where([s], s.barcode in ^codes or s.plate in ^codes)
    |> select([s, b, c, d], %{
      id: s.id,
      plate: s.plate,
      barcode: s.barcode,
      model: s.model,
      status: s.status,
      branch_id: s.branch_id,
      branch_name: b.name,
      current_branch_id: s.current_branch_id,
      current_branch_name: c.name,
      device_type_id: s.device_type_id,
      device_type_identifier: d.device_identifier,
      device_type_category: d.category,
      device_type_name: d.device_model
    })
    |> Repo.one()
  end

  def get_scooter_by_plate_or_barcode_with_details(code) when is_binary(code) do
    codes = lookup_codes(code)
    Scooter
    |> where([s], s.barcode in ^codes or s.plate in ^codes)
    |> preload([:branch, :current_branch, :device_type])
    |> Repo.one()
  end

  def get_scooter_by_plate_or_barcode(branch_id, code) when is_binary(code) do
    codes = lookup_codes(code)

    Scooter
    |> where(
      [s],
      s.branch_id == ^branch_id and (s.barcode in ^codes or s.plate in ^codes)
    )
    |> Repo.one()
  end

  def get_scooter_by_plate_or_barcode_with_details(branch_id, code) when is_binary(code) do
    codes = lookup_codes(code)

    Scooter
    |> where(
      [s],
      s.branch_id == ^branch_id and (s.barcode in ^codes or s.plate in ^codes)
    )
    |> preload([:branch, :device_type])
    |> Repo.one()
  end

  def get_scooter_for_branch_with_details(branch_id, scooter_id) do
    Scooter
    |> where([s], s.branch_id == ^branch_id and s.id == ^scooter_id)
    |> preload([:branch, :device_type])
    |> Repo.one()
  end

  @doc """
  Gets a single scooter.

  Raises `Ecto.NoResultsError` if the Scooter does not exist.

  ## Examples

      iex> get_scooter!(123)
      %Scooter{}

      iex> get_scooter!(456)
      ** (Ecto.NoResultsError)

  """
  def get_scooter!(id), do: Repo.get!(Scooter, id)

  def get_scooter_with_details!(id) do
    Scooter
    |> preload([:branch, :device_type])
    |> Repo.get!(id)
  end

  defp lookup_codes(code) when is_binary(code) do
    code
    |> String.trim()
    |> lookup_code_candidates()
    |> Enum.uniq()
  end

  defp lookup_code_candidates("") do
    []
  end

  defp lookup_code_candidates(code) do
    uri = URI.parse(code)

    query_candidates =
      uri.query
      |> case do
        nil ->
          []

        query ->
          URI.decode_query(query)
          |> Map.values()
          |> Enum.filter(&is_binary/1)
      end

    path_candidates =
      uri.path
      |> case do
        nil ->
          []

        path ->
          path
          |> String.split("/", trim: true)
          |> Enum.filter(&(&1 != ""))
      end

    line_candidates =
      code
      |> String.split(["\n", "\r"], trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    [code, uri.fragment | query_candidates ++ path_candidates ++ line_candidates]
    |> Enum.reject(&is_nil/1)
    |> Enum.flat_map(fn candidate ->
      candidate
      |> String.trim()
      |> case do
        "" -> []
        trimmed -> [trimmed, URI.decode(trimmed)]
      end
    end)
    |> Enum.reject(&(&1 == ""))
  end

  @doc """
  Creates a scooter.

  ## Examples

      iex> create_scooter(%{field: value})
      {:ok, %Scooter{}}

      iex> create_scooter(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_scooter(attrs) do
    %Scooter{}
    |> Scooter.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a scooter.

  ## Examples

      iex> update_scooter(scooter, %{field: new_value})
      {:ok, %Scooter{}}

      iex> update_scooter(scooter, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_scooter(%Scooter{} = scooter, attrs) do
    scooter
    |> Scooter.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a scooter.

  ## Examples

      iex> delete_scooter(scooter)
      {:ok, %Scooter{}}

      iex> delete_scooter(scooter)
      {:error, %Ecto.Changeset{}}

  """
  def delete_scooter(%Scooter{} = scooter) do
    Repo.delete(scooter)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking scooter changes.

  ## Examples

      iex> change_scooter(scooter)
      %Ecto.Changeset{data: %Scooter{}}

  """
  def change_scooter(%Scooter{} = scooter, attrs \\ %{}) do
    Scooter.changeset(scooter, attrs)
  end
  def update_current_locations([], _branch_id), do: {0, nil}

  def update_current_locations(scooter_ids, branch_id) do
    Scooter
    |> where([s], s.id in ^scooter_ids)
    |> Repo.update_all(set: [current_branch_id: branch_id, updated_at: DateTime.utc_now() |> DateTime.truncate(:second)])
  end


end
