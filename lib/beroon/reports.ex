defmodule Beroon.Reports do
  @moduledoc """
  The Reports context.
  """

  import Ecto.Query, warn: false
  alias Beroon.Repo
  alias Beroon.Checklists.ChecklistItem
  alias Beroon.Fleet.DeviceType
  alias Beroon.Fleet.Scooter
  alias Beroon.Operations.Branch
  alias Beroon.Reports.EveningCountItem
  alias Beroon.Reports.MorningInspectionItem
  alias Beroon.Reports.ScooterLocationAlert

  alias Beroon.Reports.EveningCount

  @doc """
  Returns the list of evening_counts.

  ## Examples

      iex> list_evening_counts()
      [%EveningCount{}, ...]

  """
  def list_evening_counts do
    EveningCount
    |> order_by([e], desc: e.counted_at)
    |> Repo.all()
  end

  def list_evening_counts_for_date(date) do
    counts =
      EveningCount
      |> join(:left, [e], b in Branch, on: b.id == e.branch_id)
      |> where([e], e.counted_on == ^date)
      |> order_by([e, b], asc: b.name)
      |> select([e, b], %{
        id: e.id,
        branch_name: b.name,
        manager_name: e.manager_name,
        total_count: e.total_count,
        available_count: e.available_count,
        rented_count: e.rented_count,
        damaged_count: e.damaged_count,
        missing_count: e.missing_count,
        counted_at: e.counted_at,
        notes: e.notes
      })
      |> Repo.all()

    items_by_count =
      EveningCountItem
      |> join(:inner, [i], s in Scooter, on: s.id == i.scooter_id)
      |> join(:left, [i, s], b in Branch, on: b.id == s.branch_id)
      |> join(:left, [i, s, b], d in DeviceType, on: d.id == s.device_type_id)
      |> where([i], i.evening_count_id in ^Enum.map(counts, & &1.id))
      |> order_by([i, s], asc: s.plate)
      |> select([i, s, b, d], %{
        evening_count_id: i.evening_count_id,
        scooter_id: s.id,
        plate: s.plate,
        barcode: s.barcode,
        branch_name: b.name,
        device_type_name: d.device_model,
        device_type_identifier: d.device_identifier,
        device_type_category: d.category
      })
      |> Repo.all()
      |> Enum.group_by(& &1.evening_count_id)

    Enum.map(counts, &Map.put(&1, :items, Map.get(items_by_count, &1.id, [])))
  end

  @doc """
  Gets a single evening_count.

  Raises `Ecto.NoResultsError` if the Evening count does not exist.

  ## Examples

      iex> get_evening_count!(123)
      %EveningCount{}

      iex> get_evening_count!(456)
      ** (Ecto.NoResultsError)

  """
  def get_evening_count!(id), do: Repo.get!(EveningCount, id)

  @doc """
  Creates a evening_count.

  ## Examples

      iex> create_evening_count(%{field: value})
      {:ok, %EveningCount{}}

      iex> create_evening_count(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_evening_count(attrs) do
    %EveningCount{}
    |> EveningCount.changeset(attrs)
    |> Repo.insert()
  end

  def create_evening_count_with_items(attrs, scanned_scooters) do
    Repo.transaction(fn ->
      evening_count =
        case create_evening_count(attrs) do
          {:ok, evening_count} -> evening_count
          {:error, changeset} -> Repo.rollback(changeset)
        end

      scanned_scooters
      |> Enum.uniq_by(& &1.id)
      |> Enum.each(fn scooter ->
        %EveningCountItem{}
        |> EveningCountItem.changeset(%{
          evening_count_id: evening_count.id,
          scooter_id: scooter.id,
          scanned_code: scooter.barcode || scooter.plate
        })
        |> Repo.insert!()
      end)

      create_location_alerts(evening_count, attrs, scanned_scooters)

      evening_count
    end)
  end

  defp create_location_alerts(evening_count, attrs, scanned_scooters) do
    detected_branch_id = evening_count.branch_id

    scanned_scooters
    |> Enum.uniq_by(& &1.id)
    |> Enum.filter(&(&1.branch_id && &1.branch_id != detected_branch_id))
    |> Enum.each(fn scooter ->
      %ScooterLocationAlert{}
      |> ScooterLocationAlert.changeset(%{
        scooter_id: scooter.id,
        home_branch_id: scooter.branch_id,
        detected_branch_id: detected_branch_id,
        evening_count_id: evening_count.id,
        detected_on: evening_count.counted_on,
        detected_at: evening_count.counted_at,
        detected_by_manager_name: attrs["manager_name"] || attrs[:manager_name],
        detected_by_manager_phone: attrs["manager_phone"] || attrs[:manager_phone],
        resolved: false
      })
      |> Repo.insert(
        on_conflict: :nothing,
        conflict_target: [:scooter_id, :home_branch_id, :detected_branch_id, :detected_on]
      )
    end)
  end

  def list_location_alerts_for_date(date) do
    location_alert_base_query()
    |> where([a, s, h, d, t], a.detected_on == ^date)
    |> order_by([a], desc: a.detected_at)
    |> Repo.all()
  end

  def list_open_location_alerts_for_home_branch(branch_id) do
    location_alert_base_query()
    |> where([a, s, h, d, t], a.home_branch_id == ^branch_id and a.resolved == false)
    |> order_by([a], desc: a.detected_at)
    |> limit(10)
    |> Repo.all()
  end

  defp location_alert_base_query do
    ScooterLocationAlert
    |> join(:inner, [a], s in Scooter, on: s.id == a.scooter_id)
    |> join(:inner, [a, s], h in Branch, on: h.id == a.home_branch_id)
    |> join(:inner, [a, s, h], d in Branch, on: d.id == a.detected_branch_id)
    |> join(:left, [a, s, h, d], t in DeviceType, on: t.id == s.device_type_id)
    |> select([a, s, h, d, t], %{
      id: a.id,
      scooter_id: s.id,
      plate: s.plate,
      barcode: s.barcode,
      model: s.model,
      scooter_status: s.status,
      home_branch_id: h.id,
      home_branch_name: h.name,
      detected_branch_id: d.id,
      detected_branch_name: d.name,
      detected_on: a.detected_on,
      detected_at: a.detected_at,
      detected_by_manager_name: a.detected_by_manager_name,
      detected_by_manager_phone: a.detected_by_manager_phone,
      resolved: a.resolved,
      device_type_identifier: t.device_identifier,
      device_type_category: t.category,
      device_type_name: t.device_model
    })
  end

  @doc """
  Updates a evening_count.

  ## Examples

      iex> update_evening_count(evening_count, %{field: new_value})
      {:ok, %EveningCount{}}

      iex> update_evening_count(evening_count, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_evening_count(%EveningCount{} = evening_count, attrs) do
    evening_count
    |> EveningCount.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a evening_count.

  ## Examples

      iex> delete_evening_count(evening_count)
      {:ok, %EveningCount{}}

      iex> delete_evening_count(evening_count)
      {:error, %Ecto.Changeset{}}

  """
  def delete_evening_count(%EveningCount{} = evening_count) do
    Repo.delete(evening_count)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking evening_count changes.

  ## Examples

      iex> change_evening_count(evening_count)
      %Ecto.Changeset{data: %EveningCount{}}

  """
  def change_evening_count(%EveningCount{} = evening_count, attrs \\ %{}) do
    EveningCount.changeset(evening_count, attrs)
  end

  alias Beroon.Reports.MorningInspection

  @doc """
  Returns the list of morning_inspections.

  ## Examples

      iex> list_morning_inspections()
      [%MorningInspection{}, ...]

  """
  def list_morning_inspections do
    MorningInspection
    |> order_by([m], desc: m.checked_at)
    |> Repo.all()
  end

  def list_morning_inspections_for_date(date) do
    inspections =
      MorningInspection
      |> join(:left, [m], b in Branch, on: b.id == m.branch_id)
      |> join(:left, [m, b], s in Scooter, on: s.id == m.scooter_id)
      |> where([m], m.checked_on == ^date)
      |> order_by([m, b, s], asc: b.name, asc: s.plate)
      |> select([m, b, s], %{
        id: m.id,
        branch_name: b.name,
        scooter_plate: s.plate,
        scooter_barcode: s.barcode,
        manager_name: m.manager_name,
        status: m.status,
        submitted_before_deadline: m.submitted_before_deadline,
        checked_at: m.checked_at,
        notes: m.notes
      })
      |> Repo.all()

    items_by_inspection =
      MorningInspectionItem
      |> join(:inner, [i], c in ChecklistItem, on: c.id == i.checklist_item_id)
      |> where([i], i.morning_inspection_id in ^Enum.map(inspections, & &1.id))
      |> order_by([i, c], asc: c.position, asc: c.title)
      |> select([i, c], %{
        morning_inspection_id: i.morning_inspection_id,
        title: c.title,
        checked: i.checked
      })
      |> Repo.all()
      |> Enum.group_by(& &1.morning_inspection_id)

    Enum.map(inspections, &Map.put(&1, :items, Map.get(items_by_inspection, &1.id, [])))
  end

  def list_morning_inspections_for_branch(date, branch_id, search_term \\ nil) do
    search_term = search_term |> to_string() |> String.trim()

    inspections =
      MorningInspection
      |> join(:inner, [m], s in Scooter, on: s.id == m.scooter_id)
      |> join(:left, [m, s], d in DeviceType, on: d.id == s.device_type_id)
      |> where([m], m.checked_on == ^date and m.branch_id == ^branch_id)
      |> filter_device_search(search_term)
      |> order_by([m, s, d], desc: m.checked_at, asc: s.plate)
      |> select([m, s, d], %{
        id: m.id,
        scooter_id: s.id,
        scooter_plate: s.plate,
        scooter_barcode: s.barcode,
        scooter_model: s.model,
        scooter_status: s.status,
        manager_name: m.manager_name,
        manager_phone: m.manager_phone,
        status: m.status,
        submitted_before_deadline: m.submitted_before_deadline,
        checked_at: m.checked_at,
        notes: m.notes,
        device_type_id: d.id,
        device_type_identifier: d.device_identifier,
        device_type_category: d.category,
        device_type_name: d.device_model
      })
      |> Repo.all()

    items_by_inspection =
      MorningInspectionItem
      |> join(:inner, [i], c in ChecklistItem, on: c.id == i.checklist_item_id)
      |> where([i], i.morning_inspection_id in ^Enum.map(inspections, & &1.id))
      |> order_by([i, c], asc: c.position, asc: c.title)
      |> select([i, c], %{
        morning_inspection_id: i.morning_inspection_id,
        title: c.title,
        checked: i.checked
      })
      |> Repo.all()
      |> Enum.group_by(& &1.morning_inspection_id)

    Enum.map(inspections, &Map.put(&1, :items, Map.get(items_by_inspection, &1.id, [])))
  end

  def count_unchecked_scooters_for_branch(date, branch_id) do
    date
    |> unchecked_scooters_query(branch_id)
    |> Repo.aggregate(:count, :id)
  end

  def list_unchecked_scooters_for_branch(date, branch_id, search_term \\ nil) do
    search_term = search_term |> to_string() |> String.trim()

    date
    |> unchecked_scooters_query(branch_id)
    |> filter_device_search(search_term)
    |> order_by([s, d], asc: s.plate)
    |> preload([s, d], device_type: d)
    |> Repo.all()
  end

  defp unchecked_scooters_query(date, branch_id) do
    checked_scooter_ids =
      MorningInspection
      |> where([m], m.checked_on == ^date and m.branch_id == ^branch_id)
      |> select([m], m.scooter_id)

    Scooter
    |> join(:left, [s], d in DeviceType, on: d.id == s.device_type_id)
    |> where([s], s.branch_id == ^branch_id)
    |> where([s], s.id not in subquery(checked_scooter_ids))
  end

  defp filter_device_search(query, ""), do: query

  defp filter_device_search(query, search_term) do
    pattern = "%#{search_term}%"

    where(
      query,
      [..., s, d],
      ilike(s.plate, ^pattern) or
        ilike(s.barcode, ^pattern) or
        ilike(s.model, ^pattern) or
        ilike(s.status, ^pattern) or
        ilike(s.notes, ^pattern) or
        fragment("CAST(? AS TEXT) ILIKE ?", s.id, ^pattern) or
        fragment("CAST(? AS TEXT) ILIKE ?", s.branch_id, ^pattern) or
        fragment("CAST(? AS TEXT) ILIKE ?", s.device_type_id, ^pattern) or
        fragment("CAST(? AS TEXT) ILIKE ?", s.inserted_at, ^pattern) or
        fragment("CAST(? AS TEXT) ILIKE ?", s.updated_at, ^pattern) or
        ilike(d.name, ^pattern) or
        ilike(d.code, ^pattern) or
        ilike(d.device_identifier, ^pattern) or
        ilike(d.category, ^pattern) or
        ilike(d.device_model, ^pattern) or
        ilike(d.description, ^pattern) or
        fragment("CAST(? AS TEXT) ILIKE ?", d.id, ^pattern) or
        fragment("CAST(? AS TEXT) ILIKE ?", d.active, ^pattern) or
        fragment("CAST(? AS TEXT) ILIKE ?", d.inserted_at, ^pattern) or
        fragment("CAST(? AS TEXT) ILIKE ?", d.updated_at, ^pattern)
    )
  end

  def count_morning_inspections_for_date(date) do
    MorningInspection
    |> where([m], m.checked_on == ^date)
    |> Repo.aggregate(:count, :id)
  end

  def morning_submitted_today?(phone, date \\ Date.utc_today()) do
    MorningInspection
    |> where([m], m.manager_phone == ^phone and m.checked_on == ^date)
    |> Repo.exists?()
  end

  def morning_scooter_submitted_today?(phone, scooter_id, date \\ Date.utc_today()) do
    MorningInspection
    |> where(
      [m],
      m.manager_phone == ^phone and m.scooter_id == ^scooter_id and m.checked_on == ^date
    )
    |> Repo.exists?()
  end

  def evening_submitted_today?(phone, date \\ Date.utc_today()) do
    EveningCount
    |> where([e], e.manager_phone == ^phone and e.counted_on == ^date)
    |> Repo.exists?()
  end

  @doc """
  Gets a single morning_inspection.

  Raises `Ecto.NoResultsError` if the Morning inspection does not exist.

  ## Examples

      iex> get_morning_inspection!(123)
      %MorningInspection{}

      iex> get_morning_inspection!(456)
      ** (Ecto.NoResultsError)

  """
  def get_morning_inspection!(id), do: Repo.get!(MorningInspection, id)

  @doc """
  Creates a morning_inspection.

  ## Examples

      iex> create_morning_inspection(%{field: value})
      {:ok, %MorningInspection{}}

      iex> create_morning_inspection(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_morning_inspection(attrs) do
    %MorningInspection{}
    |> MorningInspection.changeset(attrs)
    |> Repo.insert()
  end

  def create_morning_inspection_with_items(attrs, checklist_item_ids, checked_item_ids) do
    Repo.transaction(fn ->
      inspection =
        case create_morning_inspection(attrs) do
          {:ok, inspection} -> inspection
          {:error, changeset} -> Repo.rollback(changeset)
        end

      checked = MapSet.new(Enum.map(checked_item_ids, &to_string/1))

      Enum.each(checklist_item_ids, fn item_id ->
        %MorningInspectionItem{}
        |> MorningInspectionItem.changeset(%{
          morning_inspection_id: inspection.id,
          checklist_item_id: item_id,
          checked: MapSet.member?(checked, to_string(item_id))
        })
        |> Repo.insert!()
      end)

      inspection
    end)
  end

  @doc """
  Updates a morning_inspection.

  ## Examples

      iex> update_morning_inspection(morning_inspection, %{field: new_value})
      {:ok, %MorningInspection{}}

      iex> update_morning_inspection(morning_inspection, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_morning_inspection(%MorningInspection{} = morning_inspection, attrs) do
    morning_inspection
    |> MorningInspection.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a morning_inspection.

  ## Examples

      iex> delete_morning_inspection(morning_inspection)
      {:ok, %MorningInspection{}}

      iex> delete_morning_inspection(morning_inspection)
      {:error, %Ecto.Changeset{}}

  """
  def delete_morning_inspection(%MorningInspection{} = morning_inspection) do
    Repo.delete(morning_inspection)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking morning_inspection changes.

  ## Examples

      iex> change_morning_inspection(morning_inspection)
      %Ecto.Changeset{data: %MorningInspection{}}

  """
  def change_morning_inspection(%MorningInspection{} = morning_inspection, attrs \\ %{}) do
    MorningInspection.changeset(morning_inspection, attrs)
  end
end
