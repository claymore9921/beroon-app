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
      {"needs_service", "نیازمند تعمیر"},
      {"waiting_for_part", "در انتظار قطعه"},
      {"out_of_service", "از مدار خارج شده"}
    ]
    |> Enum.filter(fn {value, label} ->
      String.contains?(value, normalized) or String.contains?(String.downcase(label), normalized)
    end)
    |> Enum.map(&elem(&1, 0))
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

  defp maybe_filter_status(query, status)
       when status in ["active", "needs_service", "waiting_for_part", "out_of_service"] do
    where(query, [s], s.status == ^status)
  end

  defp maybe_filter_status(query, _status), do: query

  def count_scooters_for_branch(branch_id) do
    Scooter
    |> where([s], s.branch_id == ^branch_id)
    |> Repo.aggregate(:count, :id)
  end

  def get_scooter_by_barcode(branch_id, barcode) when is_binary(barcode) do
    clean_barcode = String.trim(barcode)

    Scooter
    |> where([s], s.branch_id == ^branch_id and s.barcode == ^clean_barcode)
    |> Repo.one()
  end

  def get_scooter_by_plate_or_barcode(code) when is_binary(code) do
    clean_code = String.trim(code)

    Scooter
    |> join(:left, [s], b in Beroon.Operations.Branch, on: b.id == s.branch_id)
    |> join(:left, [s, b], d in DeviceType, on: d.id == s.device_type_id)
    |> where([s], s.barcode == ^clean_code or s.plate == ^clean_code)
    |> select([s, b, d], %{
      id: s.id,
      plate: s.plate,
      barcode: s.barcode,
      model: s.model,
      status: s.status,
      branch_id: s.branch_id,
      branch_name: b.name,
      device_type_id: s.device_type_id,
      device_type_identifier: d.device_identifier,
      device_type_category: d.category,
      device_type_name: d.device_model
    })
    |> Repo.one()
  end

  def get_scooter_by_plate_or_barcode(branch_id, code) when is_binary(code) do
    clean_code = String.trim(code)

    Scooter
    |> where(
      [s],
      s.branch_id == ^branch_id and (s.barcode == ^clean_code or s.plate == ^clean_code)
    )
    |> Repo.one()
  end

  def get_scooter_by_plate_or_barcode_with_details(branch_id, code) when is_binary(code) do
    clean_code = String.trim(code)

    Scooter
    |> where(
      [s],
      s.branch_id == ^branch_id and (s.barcode == ^clean_code or s.plate == ^clean_code)
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
end
