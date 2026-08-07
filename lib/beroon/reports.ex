defmodule Beroon.Reports do
  @moduledoc """
  The Reports context.
  """

  import Ecto.Query, warn: false
  alias Beroon.Repo
  alias Beroon.Checklists.ChecklistItem
  alias Beroon.Fleet.DeviceType
  alias Beroon.Fleet.Scooter
  alias Beroon.Logistics
  alias Beroon.Operations.Branch
  alias Beroon.Reports.BranchNotification
  alias Beroon.Reports.BranchNotificationRecipient
  alias Beroon.Reports.EveningCountItem
  alias Beroon.Reports.MorningInspectionItem
  alias Beroon.Reports.ScooterLocationAlert
  alias Beroon.Reports.ScooterRepairReport
  alias Beroon.Thefts

  alias Beroon.Reports.EveningCount

  @iran_utc_offset_seconds 12_600

  @doc """
  Returns the current calendar date in Iran time (UTC+03:30).
  """
  def iran_today(now \\ DateTime.utc_now()) do
    now
    |> DateTime.add(@iran_utc_offset_seconds, :second)
    |> DateTime.to_date()
  end

  @doc """
  Returns the operational date for an evening count.

  The operational window is 21:00 through 05:59 Tehran time. Counts after
  midnight and before 06:00 belong to the previous calendar date.
  """
  def evening_report_date(now \\ DateTime.utc_now()) do
    tehran_now = tehran_now(now)
    date = DateTime.to_date(tehran_now)

    if tehran_now.hour < 6, do: Date.add(date, -1), else: date
  end

  @doc "Returns true only during the 21:00-06:00 Tehran evening-count window."
  def evening_window_open?(now \\ DateTime.utc_now()) do
    hour = tehran_now(now).hour
    hour >= 21 or hour < 6
  end

  @doc """
  Returns the evening cycle an admin/manager should currently inspect.
  Between 06:00 and 20:59 the latest completed cycle is the previous date.
  """
  def current_evening_cycle_date(now \\ DateTime.utc_now()) do
    tehran = tehran_now(now)
    date = DateTime.to_date(tehran)

    cond do
      tehran.hour < 6 -> Date.add(date, -1)
      tehran.hour >= 21 -> date
      true -> Date.add(date, -1)
    end
  end

  @doc "UTC boundaries for a report date: 21:00 Tehran to 06:00 next day."
  def evening_window_utc_bounds(%Date{} = date) do
    start_utc =
      DateTime.new!(date, ~T[21:00:00], "Etc/UTC")
      |> DateTime.add(-@iran_utc_offset_seconds, :second)
      |> DateTime.truncate(:second)

    end_utc =
      Date.add(date, 1)
      |> DateTime.new!(~T[06:00:00], "Etc/UTC")
      |> DateTime.add(-@iran_utc_offset_seconds, :second)
      |> DateTime.truncate(:second)

    {start_utc, end_utc}
  end

  defp tehran_now(%DateTime{} = now), do: DateTime.add(now, @iran_utc_offset_seconds, :second)

  def create_branch_notification(attrs, branch_ids) do
    branch_ids =
      branch_ids
      |> List.wrap()
      |> Enum.map(&to_string/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()

    Repo.transaction(fn ->
      notification =
        attrs
        |> Map.put_new("sent_at", DateTime.utc_now() |> DateTime.truncate(:second))
        |> create_notification!()

      Enum.each(branch_ids, fn branch_id ->
        %BranchNotificationRecipient{}
        |> BranchNotificationRecipient.changeset(%{
          notification_id: notification.id,
          branch_id: branch_id
        })
        |> Repo.insert!()
      end)

      notification
    end)
  end

  defp create_notification!(attrs) do
    %BranchNotification{}
    |> BranchNotification.changeset(attrs)
    |> Repo.insert!()
  end

  def list_branch_notifications(branch_id) do
    BranchNotificationRecipient
    |> join(:inner, [r], n in BranchNotification, on: n.id == r.notification_id)
    |> where([r, n], r.branch_id == ^branch_id)
    |> order_by([r, n], desc: n.sent_at)
    |> select([r, n], %{
      id: r.id,
      notification_id: n.id,
      subject: n.subject,
      sent_at: n.sent_at,
      read_at: r.read_at
    })
    |> Repo.all()
  end

  def count_unread_branch_notifications(nil), do: 0

  def count_unread_branch_notifications(branch_id) do
    BranchNotificationRecipient
    |> where([r], r.branch_id == ^branch_id and is_nil(r.read_at))
    |> Repo.aggregate(:count, :id)
  end

  def get_branch_notification_for_recipient!(branch_id, recipient_id) do
    BranchNotificationRecipient
    |> join(:inner, [r], n in BranchNotification, on: n.id == r.notification_id)
    |> where([r, n], r.id == ^recipient_id and r.branch_id == ^branch_id)
    |> select([r, n], %{
      id: r.id,
      notification_id: n.id,
      subject: n.subject,
      body: n.body,
      sent_at: n.sent_at,
      read_at: r.read_at
    })
    |> Repo.one!()
  end

  def mark_branch_notification_read(branch_id, recipient_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    BranchNotificationRecipient
    |> where([r], r.id == ^recipient_id and r.branch_id == ^branch_id and is_nil(r.read_at))
    |> Repo.update_all(set: [read_at: now])
  end

  def create_scooter_repair_report(attrs) do
    %ScooterRepairReport{}
    |> ScooterRepairReport.changeset(attrs)
    |> Repo.insert()
  end

  def repair_report_counts_by_branch do
    ScooterRepairReport
    |> join(:inner, [r], b in Branch, on: b.id == r.branch_id)
    |> group_by([r, b], [b.id, b.name])
    |> select([r, b], %{branch_id: b.id, branch_name: b.name, count: count(r.id)})
    |> order_by([r, b], desc: count(r.id), asc: b.name)
    |> Repo.all()
  end

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

    attach_evening_count_items(counts)
  end

  def reference_inventory_export do
    branches =
      Branch
      |> where([b], b.active == true and b.kind == "branch")
      |> order_by([b], asc: b.name)
      |> select([b], %{id: b.id, name: b.name})
      |> Repo.all()

    device_types =
      DeviceType
      |> order_by([d], asc: d.category, asc: d.device_model, asc: d.device_identifier)
      |> select([d], %{
        id: d.id,
        label:
          fragment(
            "trim(concat_ws(' ', nullif(?, ''), nullif(?, ''), nullif(?, '')))",
            d.category,
            d.device_model,
            d.device_identifier
          )
      })
      |> Repo.all()

    # آمار مرجع بر اساس مالکیت/تخصیص دستگاه است، نه اسکن روزانه.
    # وضعیت‌هایی که ستون مستقل دارند از ستون شعبه خارج می‌شوند تا دوباره‌شماری نشوند.
    branch_counts =
      Scooter
      |> where(
        [s],
        not is_nil(s.branch_id) and not is_nil(s.device_type_id) and
          s.status not in ["waiting_for_part", "loaned", "stolen"]
      )
      |> group_by([s], [s.device_type_id, s.branch_id])
      |> select([s], {{s.device_type_id, s.branch_id}, count(s.id)})
      |> Repo.all()
      |> Map.new()

    waiting_for_part_counts = status_counts_by_device_type(["waiting_for_part"])
    loaned_counts = status_counts_by_device_type(["loaned"])
    stolen_counts = Thefts.open_counts_by_device_type()

    new_stock_counts =
      Beroon.Inventory.NewDeviceStock
      |> group_by([stock], stock.device_type_id)
      |> select([stock], {stock.device_type_id, sum(stock.quantity)})
      |> Repo.all()
      |> Map.new()

    rows =
      Enum.map(device_types, fn device_type ->
        per_branch =
          Map.new(branches, fn branch ->
            {branch.id, Map.get(branch_counts, {device_type.id, branch.id}, 0)}
          end)

        branches_total = Enum.sum(Map.values(per_branch))
        waiting_for_part = Map.get(waiting_for_part_counts, device_type.id, 0) || 0
        new_stock = Map.get(new_stock_counts, device_type.id, 0) || 0
        loaned = Map.get(loaned_counts, device_type.id, 0) || 0
        stolen = Map.get(stolen_counts, device_type.id, 0) || 0

        %{
          device_type: device_type,
          branch_counts: per_branch,
          branches_total_count: branches_total,
          waiting_for_part_count: waiting_for_part,
          new_stock_count: new_stock,
          loaned_count: loaned,
          stolen_count: stolen,
          grand_total_count: branches_total + waiting_for_part + new_stock + loaned + stolen
        }
      end)

    branch_totals =
      Map.new(branches, fn branch ->
        {branch.id,
         Enum.reduce(rows, 0, fn row, acc ->
           acc + Map.get(row.branch_counts, branch.id, 0)
         end)}
      end)

    totals = %{
      branch_counts: branch_totals,
      branches_total_count: Enum.sum(Map.values(branch_totals)),
      waiting_for_part_count: Enum.reduce(rows, 0, &(&1.waiting_for_part_count + &2)),
      new_stock_count: Enum.reduce(rows, 0, &(&1.new_stock_count + &2)),
      loaned_count: Enum.reduce(rows, 0, &(&1.loaned_count + &2)),
      stolen_count: Enum.reduce(rows, 0, &(&1.stolen_count + &2)),
      grand_total_count: Enum.reduce(rows, 0, &(&1.grand_total_count + &2))
    }

    %{
      date: iran_today(),
      branches: branches,
      rows: rows,
      totals: totals,
      loan_details: Logistics.list_open_loans()
    }
  end

  def evening_inventory_export(%Date{} = date) do
    branches =
      Branch
      |> where([b], b.active == true and b.kind == "branch")
      |> order_by([b], asc: b.name)
      |> select([b], %{id: b.id, name: b.name})
      |> Repo.all()

    # همه نوع‌های ثبت‌شده، حتی نوع‌های غیرفعال و نوع‌هایی که مقدارشان صفر است،
    # باید در خروجی کنترل روزانه باقی بمانند.
    device_types =
      DeviceType
      |> order_by([d], asc: d.category, asc: d.device_model, asc: d.device_identifier)
      |> select([d], %{
        id: d.id,
        label:
          fragment(
            "trim(concat_ws(' ', nullif(?, ''), nullif(?, ''), nullif(?, '')))",
            d.category,
            d.device_model,
            d.device_identifier
          )
      })
      |> Repo.all()

    # هر دستگاهی که در این شعبه به‌صورت معتبر اسکن شده (مالک یا دستگاه جابه‌جا شده)
    # در آمار همان شعبه محاسبه می‌شود. حمل‌ونقل غیرمالک پیش از ثبت رد می‌شود.
    # دستگاهی که اکنون در تعمیرگاه، در انتظار قطعه یا امانی است از ستون شعب حذف می‌شود
    # تا در جمع نهایی دوبار شمرده نشود.
    branch_scan_counts =
      EveningCountItem
      |> join(:inner, [i], e in EveningCount, on: e.id == i.evening_count_id)
      |> join(:inner, [i, e], s in Scooter, on: s.id == i.scooter_id)
      |> where(
        [i, e, s],
        e.counted_on == ^date and
          (i.scan_result in ["expected", "foreign"] or is_nil(i.scan_result)) and
          s.status not in [
            "needs_service",
            "awaiting_repair",
            "repairing",
            "ready_for_pickup",
            "waiting_for_part",
            "loaned",
            "stolen",
            "out_of_service"
          ] and
          not is_nil(s.device_type_id)
      )
      |> group_by([i, e, s], [e.branch_id, s.device_type_id])
      |> select([i, e, s], {{s.device_type_id, e.branch_id}, count(i.id)})
      |> Repo.all()
      |> Map.new()

    # چرخه تعمیرگاه در پروژه به این وضعیت‌ها نگاشت شده است:
    # needs_service: ارسال‌شده و در انتظار پذیرش تعمیرگاه
    # awaiting_repair: پذیرش‌شده و در انتظار شروع تعمیر
    # repairing: در حال تعمیر
    # ready_for_pickup: ترخیص‌شده و هنوز توسط شعبه تحویل گرفته نشده
    pending_acceptance_counts = status_counts_by_device_type(["needs_service"])
    accepted_waiting_repair_counts = status_counts_by_device_type(["awaiting_repair"])
    repairing_counts = status_counts_by_device_type(["repairing"])
    ready_for_pickup_counts = status_counts_by_device_type(["ready_for_pickup"])
    waiting_for_part_counts = status_counts_by_device_type(["waiting_for_part"])
    loaned_counts = status_counts_by_device_type(["loaned"])
    stolen_counts = Thefts.open_counts_by_device_type()
    stolen_breakdown = Thefts.open_breakdown()

    new_stock_counts =
      Beroon.Inventory.NewDeviceStock
      |> group_by([stock], stock.device_type_id)
      |> select([stock], {stock.device_type_id, sum(stock.quantity)})
      |> Repo.all()
      |> Map.new()

    sold_counts =
      Beroon.Inventory.Sale
      |> group_by([sale], sale.device_type_id)
      |> select([sale], {sale.device_type_id, sum(sale.quantity)})
      |> Repo.all()
      |> Map.new()

    rows =
      Enum.map(device_types, fn device_type ->
        branch_counts =
          Map.new(branches, fn branch ->
            {branch.id, Map.get(branch_scan_counts, {device_type.id, branch.id}, 0)}
          end)

        branches_total_count = Enum.sum(Map.values(branch_counts))
        pending_acceptance_count = Map.get(pending_acceptance_counts, device_type.id, 0)

        accepted_waiting_repair_count =
          Map.get(accepted_waiting_repair_counts, device_type.id, 0)

        repairing_count = Map.get(repairing_counts, device_type.id, 0)
        ready_for_pickup_count = Map.get(ready_for_pickup_counts, device_type.id, 0)

        workshop_total_count =
          pending_acceptance_count + accepted_waiting_repair_count + repairing_count +
            ready_for_pickup_count

        waiting_for_part_count = Map.get(waiting_for_part_counts, device_type.id, 0)
        loaned_count = Map.get(loaned_counts, device_type.id, 0)
        stolen_count = Map.get(stolen_counts, device_type.id, 0) || 0

        # جمع ناوگان روز فقط از دستگاه‌های موجود در چرخه عملیاتی تشکیل می‌شود؛
        # انبار نو و فروش برای اطلاع در ستون‌های جدا نمایش داده می‌شوند.
        operational_total_count =
          branches_total_count + workshop_total_count + waiting_for_part_count + loaned_count +
            stolen_count

        %{
          device_type: device_type,
          branch_counts: branch_counts,
          branches_total_count: branches_total_count,
          pending_acceptance_count: pending_acceptance_count,
          accepted_waiting_repair_count: accepted_waiting_repair_count,
          repairing_count: repairing_count,
          ready_for_pickup_count: ready_for_pickup_count,
          workshop_total_count: workshop_total_count,
          waiting_for_part_count: waiting_for_part_count,
          loaned_count: loaned_count,
          stolen_count: stolen_count,
          new_stock_count: Map.get(new_stock_counts, device_type.id, 0) || 0,
          sold_count: Map.get(sold_counts, device_type.id, 0) || 0,
          operational_total_count: operational_total_count
        }
      end)

    branch_totals =
      Map.new(branches, fn branch ->
        total =
          Enum.reduce(rows, 0, fn row, acc ->
            acc + Map.get(row.branch_counts, branch.id, 0)
          end)

        {branch.id, total}
      end)

    totals = %{
      branch_counts: branch_totals,
      branches_total_count: Enum.sum(Map.values(branch_totals)),
      pending_acceptance_count: Enum.reduce(rows, 0, &(&1.pending_acceptance_count + &2)),
      accepted_waiting_repair_count:
        Enum.reduce(rows, 0, &(&1.accepted_waiting_repair_count + &2)),
      repairing_count: Enum.reduce(rows, 0, &(&1.repairing_count + &2)),
      ready_for_pickup_count: Enum.reduce(rows, 0, &(&1.ready_for_pickup_count + &2)),
      workshop_total_count: Enum.reduce(rows, 0, &(&1.workshop_total_count + &2)),
      waiting_for_part_count: Enum.reduce(rows, 0, &(&1.waiting_for_part_count + &2)),
      loaned_count: Enum.reduce(rows, 0, &(&1.loaned_count + &2)),
      stolen_count: Enum.reduce(rows, 0, &(&1.stolen_count + &2)),
      new_stock_count: Enum.reduce(rows, 0, &(&1.new_stock_count + &2)),
      sold_count: Enum.reduce(rows, 0, &(&1.sold_count + &2)),
      operational_total_count: Enum.reduce(rows, 0, &(&1.operational_total_count + &2))
    }

    %{
      date: date,
      branches: branches,
      rows: rows,
      totals: totals,
      stolen_breakdown: stolen_breakdown,
      # این همان عدد کنترل روزانه است و دقیقاً برابر جمع شعب + تعمیرگاه +
      # در انتظار قطعه + امانی + سرقتی است.
      grand_total: totals.operational_total_count,
      loan_details: Logistics.list_open_loans(),
      summary: %{
        branch_evening_total_count: totals.branches_total_count,
        pending_acceptance_total_count: totals.pending_acceptance_count,
        accepted_waiting_repair_total_count: totals.accepted_waiting_repair_count,
        repairing_total_count: totals.repairing_count,
        ready_for_pickup_total_count: totals.ready_for_pickup_count,
        workshop_total_count: totals.workshop_total_count,
        waiting_for_part_total_count: totals.waiting_for_part_count,
        loaned_total_count: totals.loaned_count,
        stolen_total_count: totals.stolen_count,
        new_stock_total_count: totals.new_stock_count,
        sold_total_count: totals.sold_count,
        operational_total: totals.operational_total_count
      }
    }
  end

  defp status_counts_by_device_type(statuses) do
    Scooter
    |> where([s], s.status in ^statuses and not is_nil(s.device_type_id))
    |> group_by([s], s.device_type_id)
    |> select([s], {s.device_type_id, count(s.id)})
    |> Repo.all()
    |> Map.new()
  end

  def list_evening_report_dates_for_branch(branch_id) do
    EveningCount
    |> where([e], e.branch_id == ^branch_id)
    |> distinct([e], e.counted_on)
    |> order_by([e], desc: e.counted_on)
    |> select([e], e.counted_on)
    |> Repo.all()
  end

  def list_evening_counts_for_branch(branch_id, date \\ nil) do
    EveningCount
    |> join(:left, [e], b in Branch, on: b.id == e.branch_id)
    |> where([e], e.branch_id == ^branch_id)
    |> maybe_filter_counted_on(date)
    |> order_by([e], desc: e.counted_on, desc: e.counted_at)
    |> select([e, b], %{
      id: e.id,
      branch_name: b.name,
      manager_name: e.manager_name,
      manager_phone: e.manager_phone,
      total_count: e.total_count,
      available_count: e.available_count,
      rented_count: e.rented_count,
      damaged_count: e.damaged_count,
      missing_count: e.missing_count,
      counted_on: e.counted_on,
      counted_at: e.counted_at,
      notes: e.notes
    })
    |> Repo.all()
  end

  @doc """
  Returns the three-way audit for one branch and one evening operational date:
  scanned at the branch, moved in/out, and expected but not scanned.
  The query is bounded by the actual 21:00-06:00 Tehran window.
  """
  def branch_evening_audit_for_date(branch_id, %Date{} = date) do
    {window_start, window_end} = evening_window_utc_bounds(date)

    counts =
      EveningCount
      |> where(
        [e],
        e.branch_id == ^branch_id and e.counted_at >= ^window_start and e.counted_at < ^window_end
      )
      |> select([e], %{id: e.id, expected_scooter_ids: e.expected_scooter_ids, counted_at: e.counted_at})
      |> Repo.all()

    count_ids = Enum.map(counts, & &1.id)

    items =
      if count_ids == [] do
        []
      else
        EveningCountItem
        |> join(:inner, [i], s in Scooter, on: s.id == i.scooter_id)
        |> join(:left, [i, s], d in DeviceType, on: d.id == s.device_type_id)
        |> where([i], i.evening_count_id in ^count_ids)
        |> order_by([i, s], asc: s.plate)
        |> select([i, s, d], %{
          scooter_id: s.id,
          plate: s.plate,
          barcode: s.barcode,
          scan_result: i.scan_result,
          home_branch_id: i.home_branch_id,
          current_branch_id: i.current_branch_id,
          device_type_identifier: d.device_identifier,
          device_type_category: d.category,
          device_type_name: d.device_model
        })
        |> Repo.all()
      end

    moves =
      ScooterLocationAlert
      |> join(:inner, [a], s in Scooter, on: s.id == a.scooter_id)
      |> join(:left, [a, s], h in Branch, on: h.id == a.home_branch_id)
      |> join(:left, [a, s, h], d in Branch, on: d.id == a.detected_branch_id)
      |> join(:left, [a, s, h, d], t in DeviceType, on: t.id == s.device_type_id)
      |> where(
        [a],
        a.detected_at >= ^window_start and a.detected_at < ^window_end and
          (a.home_branch_id == ^branch_id or a.detected_branch_id == ^branch_id)
      )
      |> order_by([a], asc: a.detected_at)
      |> select([a, s, h, d, t], %{
        scooter_id: s.id,
        plate: s.plate,
        barcode: s.barcode,
        home_branch_id: a.home_branch_id,
        home_branch_name: h.name,
        detected_branch_id: a.detected_branch_id,
        detected_branch_name: d.name,
        detected_at: a.detected_at,
        device_type_identifier: t.device_identifier,
        device_type_category: t.category,
        device_type_name: t.device_model
      })
      |> Repo.all()
      |> Enum.map(fn move ->
        Map.put(move, :direction, if(move.home_branch_id == branch_id, do: :out, else: :in))
      end)
      |> Enum.uniq_by(&{&1.scooter_id, &1.direction, &1.detected_branch_id})

    moved_ids = MapSet.new(moves, & &1.scooter_id)

    scanned =
      items
      |> Enum.filter(fn item ->
        item.home_branch_id == branch_id and item.scan_result in [nil, "expected"] and
          not MapSet.member?(moved_ids, item.scooter_id)
      end)
      |> Enum.uniq_by(& &1.scooter_id)

    expected_ids = counts |> Enum.flat_map(&List.wrap(&1.expected_scooter_ids)) |> Enum.uniq()
    scanned_ids = MapSet.new(scanned, & &1.scooter_id)

    missing_ids =
      Enum.reject(expected_ids, fn scooter_id ->
        MapSet.member?(scanned_ids, scooter_id) or MapSet.member?(moved_ids, scooter_id)
      end)

    missing =
      if missing_ids == [] do
        []
      else
        Scooter
        |> join(:left, [s], d in DeviceType, on: d.id == s.device_type_id)
        |> where([s], s.id in ^missing_ids)
        |> order_by([s], asc: s.plate)
        |> select([s, d], %{
          scooter_id: s.id,
          plate: s.plate,
          barcode: s.barcode,
          device_type_identifier: d.device_identifier,
          device_type_category: d.category,
          device_type_name: d.device_model
        })
        |> Repo.all()
      end

    %{date: date, submitted: counts != [], scanned: scanned, moved: moves, missing: missing}
  end

  def get_evening_count_report!(id) do
    count =
      EveningCount
      |> join(:left, [e], b in Branch, on: b.id == e.branch_id)
      |> where([e], e.id == ^id)
      |> select([e, b], %{
        id: e.id,
        branch_id: e.branch_id,
        branch_name: b.name,
        manager_name: e.manager_name,
        manager_phone: e.manager_phone,
        total_count: e.total_count,
        available_count: e.available_count,
        rented_count: e.rented_count,
        damaged_count: e.damaged_count,
        missing_count: e.missing_count,
        counted_on: e.counted_on,
        counted_at: e.counted_at,
        notes: e.notes,
        expected_scooter_ids: e.expected_scooter_ids
      })
      |> Repo.one!()

    count
    |> List.wrap()
    |> attach_evening_count_items()
    |> List.first()
    |> attach_evening_audit()
  end

  defp maybe_filter_counted_on(query, nil), do: query

  defp maybe_filter_counted_on(query, date) do
    where(query, [e], e.counted_on == ^date)
  end

  defp attach_evening_count_items([]), do: []

  defp attach_evening_count_items(counts) do
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
        device_type_category: d.category,
        scan_result: i.scan_result,
        home_branch_id: i.home_branch_id,
        current_branch_id: i.current_branch_id
      })
      |> Repo.all()
      |> Enum.group_by(& &1.evening_count_id)

    Enum.map(counts, &Map.put(&1, :items, Map.get(items_by_count, &1.id, [])))
  end

  defp attach_evening_audit(report) do
    expected =
      Scooter
      |> join(:left, [s], d in DeviceType, on: d.id == s.device_type_id)
      |> where([s], s.id in ^List.wrap(report.expected_scooter_ids))
      |> order_by([s], asc: s.plate)
      |> select([s, d], %{
        scooter_id: s.id,
        plate: s.plate,
        barcode: s.barcode,
        device_type_identifier: d.device_identifier,
        device_type_category: d.category,
        device_type_name: d.device_model
      })
      |> Repo.all()

    expected_scanned_ids =
      report.items
      |> Enum.filter(&(&1.scan_result in [nil, "expected"]))
      |> MapSet.new(& &1.scooter_id)

    missing = Enum.reject(expected, &MapSet.member?(expected_scanned_ids, &1.scooter_id))
    foreign = Enum.filter(report.items, &(&1.scan_result in ["foreign", "transport"]))
    scanned = Enum.filter(report.items, &(&1.scan_result in [nil, "expected"]))

    report
    |> Map.put(:expected_count, length(expected))
    |> Map.put(:scanned_expected_count, length(scanned))
    |> Map.put(:missing_items, missing)
    |> Map.put(:foreign_items, foreign)
    |> Map.put(:scanned_items, scanned)
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

      affected_previous_count_ids =
        remove_scooters_from_other_evening_counts(
          evening_count.counted_on,
          evening_count.branch_id,
          Enum.map(scanned_scooters, & &1.id)
        )

      scanned_scooters
      |> Enum.uniq_by(& &1.id)
      |> Enum.each(fn scooter ->
        %EveningCountItem{}
        |> EveningCountItem.changeset(%{
          evening_count_id: evening_count.id,
          scooter_id: scooter.id,
          scanned_code: scooter.barcode || scooter.plate,
          scan_result: evening_scan_result(scooter, evening_count.branch_id),
          home_branch_id: scooter.branch_id,
          current_branch_id: scooter.current_branch_id
        })
        |> Repo.insert!()
      end)

      Enum.each(affected_previous_count_ids, &recalculate_evening_count_totals/1)
      resolve_returned_location_alerts(evening_count, scanned_scooters)
      create_location_alerts(evening_count, attrs, scanned_scooters)

      evening_count
    end)
  end


  defp evening_scan_result(scooter, branch_id) do
    if scooter.branch_id == branch_id, do: "expected", else: "foreign"
  end

  # اگر یک دستگاه در همان تاریخ عملیاتی قبلاً در آمار شعبه دیگری ثبت شده باشد،
  # با ثبت شعبه جدید از رکورد قبلی حذف می‌شود تا هر دستگاه فقط یک بار شمرده شود.
  defp remove_scooters_from_other_evening_counts(_date, _branch_id, []), do: []

  defp remove_scooters_from_other_evening_counts(date, branch_id, scooter_ids) do
    unique_scooter_ids = Enum.uniq(scooter_ids)

    rows =
      EveningCountItem
      |> join(:inner, [i], c in EveningCount, on: c.id == i.evening_count_id)
      |> where(
        [i, c],
        i.scooter_id in ^unique_scooter_ids and c.counted_on == ^date and
          c.branch_id != ^branch_id
      )
      |> select([i, c], {i.id, c.id})
      |> Repo.all()

    item_ids = Enum.map(rows, &elem(&1, 0))
    count_ids = rows |> Enum.map(&elem(&1, 1)) |> Enum.uniq()

    if item_ids != [] do
      EveningCountItem
      |> where([i], i.id in ^item_ids)
      |> Repo.delete_all()
    end

    count_ids
  end

  defp recalculate_evening_count_totals(count_id) do
    count = Repo.get!(EveningCount, count_id)

    counted_scooter_ids =
      EveningCountItem
      |> where([i], i.evening_count_id == ^count_id)
      |> where([i], is_nil(i.scan_result) or i.scan_result in ["expected", "foreign"])
      |> select([i], i.scooter_id)
      |> Repo.all()
      |> Enum.uniq()

    expected_scanned_ids =
      EveningCountItem
      |> where([i], i.evening_count_id == ^count_id)
      |> where([i], is_nil(i.scan_result) or i.scan_result == "expected")
      |> select([i], i.scooter_id)
      |> Repo.all()
      |> Enum.uniq()

    expected_ids = count.expected_scooter_ids || []
    missing_count = Enum.count(expected_ids -- expected_scanned_ids)
    total_count = length(counted_scooter_ids)

    count
    |> EveningCount.changeset(%{
      total_count: total_count,
      available_count: total_count,
      missing_count: missing_count
    })
    |> Repo.update!()
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

  defp resolve_returned_location_alerts(evening_count, scanned_scooters) do
    returned_scooter_ids =
      scanned_scooters
      |> Enum.uniq_by(& &1.id)
      |> Enum.filter(&(&1.branch_id == evening_count.branch_id))
      |> Enum.map(& &1.id)

    if returned_scooter_ids != [] do
      ScooterLocationAlert
      |> where(
        [a],
        a.resolved == false and
          a.home_branch_id == ^evening_count.branch_id and
          a.scooter_id in ^returned_scooter_ids
      )
      |> Repo.update_all(set: [resolved: true])
    end
  end

  def list_location_alerts_for_date(date) do
    location_alert_base_query()
    |> where([a, s, h, d, t], a.detected_on == ^date)
    |> order_by([a], desc: a.detected_at)
    |> Repo.all()
  end

  def list_open_location_alerts_for_date(date) do
    location_alert_base_query()
    |> where([a, s, h, d, t], a.detected_on == ^date and a.resolved == false)
    |> order_by([a], desc: a.detected_at)
    |> Repo.all()
  end

  def list_location_alert_dates do
    ScooterLocationAlert
    |> distinct([a], a.detected_on)
    |> order_by([a], desc: a.detected_on)
    |> select([a], a.detected_on)
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

  def list_unhealthy_scooters_for_branch(date, branch_id) do
    list_morning_inspections_for_branch(date, branch_id)
    |> Enum.filter(fn inspection ->
      inspection.scooter_status not in ["needs_service", "awaiting_repair", "repairing", "waiting_for_part", "ready_for_pickup", "out_of_service", "loaned", "stolen"] and
        Enum.any?(inspection.items, fn item -> not item.checked end)
    end)
    |> Enum.map(fn inspection ->
      Map.put(inspection, :unchecked_items, Enum.filter(inspection.items, fn item -> not item.checked end))
    end)
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
    |> where([s], s.branch_id == ^branch_id and s.status not in ["loaned", "stolen"])
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


  def list_morning_scanned_scooters(branch_id, date \\ iran_today()) do
    MorningInspection
    |> join(:inner, [m], s in Scooter, on: s.id == m.scooter_id)
    |> join(:left, [m, s], d in DeviceType, on: d.id == s.device_type_id)
    |> where([m], m.branch_id == ^branch_id and m.checked_on == ^date)
    |> order_by([m, s], desc: m.checked_at, asc: s.plate)
    |> select([m, s, d], %{
      id: s.id,
      plate: s.plate,
      barcode: s.barcode,
      status: s.status,
      checked_at: m.checked_at,
      device_type: d
    })
    |> Repo.all()
  end

  def list_scooters_not_scanned_since(hours \\ 48) do
    cutoff = DateTime.utc_now() |> DateTime.add(-hours * 3600, :second)

    morning_scans =
      MorningInspection
      |> group_by([m], m.scooter_id)
      |> select([m], {m.scooter_id, max(m.checked_at)})
      |> Repo.all()
      |> Map.new()

    evening_scans =
      EveningCountItem
      |> group_by([i], i.scooter_id)
      |> select([i], {i.scooter_id, max(i.inserted_at)})
      |> Repo.all()
      |> Map.new()

    Scooter
    |> where([s], s.status != "stolen")
    |> preload([:branch, :current_branch, :device_type])
    |> Repo.all()
    |> Enum.map(fn scooter ->
      last_scan = latest_datetime(Map.get(morning_scans, scooter.id), Map.get(evening_scans, scooter.id))
      Map.put(scooter, :last_scan_at, last_scan)
    end)
    |> Enum.filter(fn scooter -> is_nil(scooter.last_scan_at) or DateTime.compare(scooter.last_scan_at, cutoff) == :lt end)
    |> Enum.sort_by(fn scooter -> scooter.last_scan_at || ~U[1970-01-01 00:00:00Z] end, DateTime)
  end

  defp latest_datetime(nil, nil), do: nil
  defp latest_datetime(%DateTime{} = value, nil), do: value
  defp latest_datetime(nil, %DateTime{} = value), do: value
  defp latest_datetime(%DateTime{} = first, %DateTime{} = second) do
    if DateTime.compare(first, second) in [:gt, :eq], do: first, else: second
  end

  def count_morning_inspections_for_date(date) do
    MorningInspection
    |> where([m], m.checked_on == ^date)
    |> Repo.aggregate(:count, :id)
  end

  def morning_submitted_today?(branch_id, date \\ iran_today()) do
    MorningInspection
    |> where([m], m.branch_id == ^branch_id and m.checked_on == ^date)
    |> Repo.exists?()
  end

  def morning_scooter_submitted_today?(branch_id, scooter_id, date \\ iran_today()) do
    MorningInspection
    |> where(
      [m],
      m.branch_id == ^branch_id and m.scooter_id == ^scooter_id and m.checked_on == ^date
    )
    |> Repo.exists?()
  end

  def branch_report_statuses(branches, date \\ iran_today()) do
    branch_ids = Enum.map(branches, & &1.id)

    morning_branch_ids =
      MorningInspection
      |> where([m], m.branch_id in ^branch_ids and m.checked_on == ^date)
      |> distinct([m], m.branch_id)
      |> select([m], m.branch_id)
      |> Repo.all()
      |> MapSet.new()

    evening_date = Date.add(date, -1)
    {evening_start, evening_end} = evening_window_utc_bounds(evening_date)

    evening_branch_ids =
      EveningCount
      |> where(
        [e],
        e.branch_id in ^branch_ids and e.counted_at >= ^evening_start and e.counted_at < ^evening_end
      )
      |> distinct([e], e.branch_id)
      |> select([e], e.branch_id)
      |> Repo.all()
      |> MapSet.new()

    Enum.map(branches, fn branch ->
      %{
        branch: branch,
        morning_submitted: MapSet.member?(morning_branch_ids, branch.id),
        evening_submitted: MapSet.member?(evening_branch_ids, branch.id)
      }
    end)
  end

  def evening_submitted_for_cycle?(branch_id, now \\ DateTime.utc_now())
  def evening_submitted_for_cycle?(nil, _now), do: false

  def evening_submitted_for_cycle?(branch_id, %DateTime{} = now) do
    date = current_evening_cycle_date(now)
    {window_start, window_end} = evening_window_utc_bounds(date)

    EveningCount
    |> where(
      [e],
      e.branch_id == ^branch_id and e.counted_at >= ^window_start and e.counted_at < ^window_end
    )
    |> Repo.exists?()
  end

  def evening_submission_locked?(branch_id, now \\ DateTime.utc_now())
  def evening_submission_locked?(nil, _now), do: true

  def evening_submission_locked?(branch_id, %DateTime{} = now) do
    not evening_window_open?(now) or evening_submitted_for_cycle?(branch_id, now)
  end

  # Kept for compatibility with older callers.
  def evening_submitted_today?(phone, date \\ iran_today()) do
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

  alias Beroon.Reports.{DailyRevenue, WorkshopEvent}

  def get_daily_revenue(branch_id, date) do
    Repo.get_by(DailyRevenue, branch_id: branch_id, reported_on: date)
  end

  def upsert_daily_revenue(attrs) do
    branch_id = attrs[:branch_id] || attrs["branch_id"]
    date = attrs[:reported_on] || attrs["reported_on"]

    case get_daily_revenue(branch_id, date) do
      nil -> %DailyRevenue{} |> DailyRevenue.changeset(attrs) |> Repo.insert()
      revenue -> revenue |> DailyRevenue.changeset(attrs) |> Repo.update()
    end
  end

  def create_workshop_event(attrs) do
    %WorkshopEvent{} |> WorkshopEvent.changeset(attrs) |> Repo.insert()
  end

  def workshop_stats(from_date, to_date) do
    WorkshopEvent
    |> where([e], e.event_on >= ^from_date and e.event_on <= ^to_date)
    |> group_by([e], [e.event_on, e.event_type])
    |> select([e], {e.event_on, e.event_type, count(e.id)})
    |> Repo.all()
    |> Enum.group_by(fn {date, _type, _count} -> date end)
    |> Enum.map(fn {date, rows} ->
      counts = Map.new(rows, fn {_date, type, count} -> {type, count} end)
      %{date: date, accepted: Map.get(counts, "accepted", 0), repair_started: Map.get(counts, "repair_started", 0), discharged: Map.get(counts, "discharged", 0)}
    end)
    |> Enum.sort_by(& &1.date, Date)
    |> Enum.reverse()
  end

end
