defmodule Beroon.Scripts.ExportAssignedInventoryReport do
  @moduledoc false

  import Ecto.Query, warn: false

  alias Beroon.Fleet.Scooter
  alias Beroon.Repo
  alias Beroon.Reports

  @excluded_branch_statuses [
    "needs_service",
    "awaiting_repair",
    "repairing",
    "ready_for_pickup",
    "waiting_for_part",
    "loaned",
    "stolen",
    "out_of_service"
  ]

  def run do
    date = Reports.iran_today()

    export =
      date
      |> Reports.evening_inventory_export()
      |> replace_evening_counts_with_assigned_counts()

    output_dir = Path.expand("exports", File.cwd!())
    File.mkdir_p!(output_dir)

    persian_date = Beroon.Calendar.persian_numeric_date(date)
    safe_date = String.replace(persian_date, "/", "-")
    output_path = Path.join(output_dir, "beroon-assigned-inventory-#{safe_date}.xls")

    File.write!(output_path, render_xls(export))

    IO.puts("\nگزارش با موفقیت ساخته شد:")
    IO.puts(output_path)
    IO.puts("تاریخ گزارش: #{persian_date}")
    IO.puts("جمع دستگاه‌های تخصیص‌یافته به شعب: #{export.totals.branches_total_count}")
    IO.puts("جمع کل ناوگان: #{export.totals.operational_total_count}\n")
  end

  defp replace_evening_counts_with_assigned_counts(export) do
    assigned_counts = assigned_counts_by_device_type_and_branch()

    rows =
      Enum.map(export.rows, fn row ->
        branch_counts =
          Map.new(export.branches, fn branch ->
            count = Map.get(assigned_counts, {row.device_type.id, branch.id}, 0)
            {branch.id, count}
          end)

        branches_total_count = Enum.sum(Map.values(branch_counts))

        operational_total_count =
          branches_total_count +
            row.workshop_total_count +
            row.waiting_for_part_count +
            row.loaned_count +
            row.stolen_count

        row
        |> Map.put(:branch_counts, branch_counts)
        |> Map.put(:branches_total_count, branches_total_count)
        |> Map.put(:operational_total_count, operational_total_count)
      end)

    branch_totals =
      Map.new(export.branches, fn branch ->
        total =
          Enum.reduce(rows, 0, fn row, acc ->
            acc + Map.get(row.branch_counts, branch.id, 0)
          end)

        {branch.id, total}
      end)

    branches_total_count = Enum.sum(Map.values(branch_totals))
    operational_total_count = Enum.reduce(rows, 0, &(&1.operational_total_count + &2))

    totals =
      export.totals
      |> Map.put(:branch_counts, branch_totals)
      |> Map.put(:branches_total_count, branches_total_count)
      |> Map.put(:operational_total_count, operational_total_count)

    summary =
      export.summary
      |> Map.put(:branch_evening_total_count, branches_total_count)
      |> Map.put(:operational_total, operational_total_count)

    export
    |> Map.put(:rows, rows)
    |> Map.put(:totals, totals)
    |> Map.put(:summary, summary)
    |> Map.put(:grand_total, operational_total_count)
  end

  defp assigned_counts_by_device_type_and_branch do
    Scooter
    |> where(
      [s],
      not is_nil(s.branch_id) and
        not is_nil(s.device_type_id) and
        s.status not in ^@excluded_branch_statuses
    )
    |> group_by([s], [s.device_type_id, s.branch_id])
    |> select([s], {{s.device_type_id, s.branch_id}, count(s.id)})
    |> Repo.all()
    |> Map.new()
  end

  defp render_xls(export) do
    header_cells =
      [
        "<th>نوع دستگاه</th>",
        Enum.map(export.branches, fn branch -> "<th>#{escape_html(branch.name)}</th>" end),
        "<th>جمع کل شعب</th>",
        "<th>ارسال‌شده؛ در انتظار پذیرش تعمیرگاه</th>",
        "<th>پذیرش‌شده؛ در انتظار تعمیر</th>",
        "<th>در حال تعمیر</th>",
        "<th>ترخیص‌شده؛ تحویل شعبه نشده</th>",
        "<th>جمع تعمیرگاه</th>",
        "<th>در انتظار قطعه</th>",
        "<th>دستگاه‌های امانی</th>",
        "<th>دستگاه‌های سرقتی</th>",
        "<th>انبار دستگاه‌های نو</th>",
        "<th>فروش‌رفته</th>",
        "<th>جمع ناوگان روز</th>"
      ]

    body_rows =
      Enum.map(export.rows, fn row ->
        branch_cells =
          Enum.map(export.branches, fn branch ->
            "<td>#{Map.get(row.branch_counts, branch.id, 0)}</td>"
          end)

        [
          "<tr>",
          "<td>#{escape_html(row.device_type.label)}</td>",
          branch_cells,
          ~s(<td class="branches-total"><strong>#{row.branches_total_count}</strong></td>),
          "<td>#{row.pending_acceptance_count}</td>",
          "<td>#{row.accepted_waiting_repair_count}</td>",
          "<td>#{row.repairing_count}</td>",
          "<td>#{row.ready_for_pickup_count}</td>",
          ~s(<td class="workshop-total"><strong>#{row.workshop_total_count}</strong></td>),
          "<td>#{row.waiting_for_part_count}</td>",
          "<td>#{row.loaned_count}</td>",
          "<td>#{row.stolen_count}</td>",
          "<td>#{row.new_stock_count}</td>",
          "<td>#{row.sold_count}</td>",
          ~s(<td class="operational-total-cell"><strong>#{row.operational_total_count}</strong></td>),
          "</tr>"
        ]
      end)

    total_branch_cells =
      Enum.map(export.branches, fn branch ->
        "<td><strong>#{Map.get(export.totals.branch_counts, branch.id, 0)}</strong></td>"
      end)

    total_row = [
      ~s(<tr class="total-row">),
      "<td><strong>جمع هر ستون</strong></td>",
      total_branch_cells,
      "<td><strong>#{export.totals.branches_total_count}</strong></td>",
      "<td><strong>#{export.totals.pending_acceptance_count}</strong></td>",
      "<td><strong>#{export.totals.accepted_waiting_repair_count}</strong></td>",
      "<td><strong>#{export.totals.repairing_count}</strong></td>",
      "<td><strong>#{export.totals.ready_for_pickup_count}</strong></td>",
      "<td><strong>#{export.totals.workshop_total_count}</strong></td>",
      "<td><strong>#{export.totals.waiting_for_part_count}</strong></td>",
      "<td><strong>#{export.totals.loaned_count}</strong></td>",
      "<td><strong>#{export.totals.stolen_count}</strong></td>",
      "<td><strong>#{export.totals.new_stock_count}</strong></td>",
      "<td><strong>#{export.totals.sold_count}</strong></td>",
      "<td><strong>#{export.totals.operational_total_count}</strong></td>",
      "</tr>"
    ]

    column_count = length(export.branches) + 13

    stolen_breakdown_rows =
      export.stolen_breakdown
      |> Enum.map(fn item ->
        label =
          [item.device_identifier, item.category, item.device_model]
          |> Enum.reject(&(&1 in [nil, ""]))
          |> Enum.join(" - ")

        "<tr><td>#{escape_html(item.branch_name)}</td><td>#{escape_html(label)}</td><td>#{item.quantity}</td></tr>"
      end)
      |> IO.iodata_to_binary()

    [
      "\uFEFF",
      """
      <html>
        <head>
          <meta charset="UTF-8" />
          <style>
            body { font-family: Tahoma, Arial, sans-serif; direction: rtl; }
            table { border-collapse: collapse; direction: rtl; }
            th, td { border: 1px solid #999; padding: 8px 12px; text-align: center; }
            th { background: #ccf1ee; font-weight: bold; }
            td:first-child, th:first-child { text-align: right; min-width: 220px; }
            .branches-total { background: #eef7ff; }
            .workshop-total { background: #fff2de; }
            .operational-total-cell { background: #e7f7e7; }
            .total-row td { background: #e9f7f5; border-top: 3px solid #287f78; }
            .summary-title td { background: #dfe9f7; font-size: 16px; border-top: 4px solid #365f91; text-align: right; }
            .summary-row td { background: #f7f7f7; text-align: right; }
            .workshop-summary td { background: #fff8e8; text-align: right; }
            .operational-total td { background: #dff4df; font-size: 17px; border-top: 4px solid #2d7a2d; text-align: right; }
            .reference-row td { background: #f2f2f2; color: #444; text-align: right; }
          </style>
        </head>
        <body>
          <h3>گزارش موجودی تخصیص‌یافته ناوگان - #{escape_html(Beroon.Calendar.persian_date(export.date))}</h3>
          <p>ستون هر شعبه بر اساس دستگاه‌های متعلق به همان شعبه در جدول دستگاه‌ها محاسبه شده است و به ثبت آمار شبانه وابسته نیست.</p>
          <table>
            <thead>
              <tr>#{IO.iodata_to_binary(header_cells)}</tr>
            </thead>
            <tbody>
              #{IO.iodata_to_binary(body_rows)}
              #{IO.iodata_to_binary(total_row)}

              <tr class="summary-title">
                <td colspan="#{column_count}"><strong>جمع‌بندی موجودی تخصیص‌یافته</strong></td>
              </tr>
              <tr class="summary-row">
                <td colspan="#{column_count}"><strong>جمع کل دستگاه‌های متعلق به تمام شعب: #{export.summary.branch_evening_total_count}</strong></td>
              </tr>
              <tr class="workshop-summary">
                <td colspan="#{column_count}"><strong>ارسال‌شده و در انتظار پذیرش تعمیرگاه: #{export.summary.pending_acceptance_total_count}</strong></td>
              </tr>
              <tr class="workshop-summary">
                <td colspan="#{column_count}"><strong>پذیرش‌شده و در انتظار شروع تعمیر: #{export.summary.accepted_waiting_repair_total_count}</strong></td>
              </tr>
              <tr class="workshop-summary">
                <td colspan="#{column_count}"><strong>در حال تعمیر: #{export.summary.repairing_total_count}</strong></td>
              </tr>
              <tr class="workshop-summary">
                <td colspan="#{column_count}"><strong>ترخیص‌شده و هنوز تحویل شعبه نشده: #{export.summary.ready_for_pickup_total_count}</strong></td>
              </tr>
              <tr class="workshop-summary">
                <td colspan="#{column_count}"><strong>جمع کل دستگاه‌های تعمیرگاهی: #{export.summary.workshop_total_count}</strong></td>
              </tr>
              <tr class="summary-row">
                <td colspan="#{column_count}"><strong>تعداد کل دستگاه‌های در انتظار قطعه: #{export.summary.waiting_for_part_total_count}</strong></td>
              </tr>
              <tr class="summary-row">
                <td colspan="#{column_count}"><strong>تعداد کل دستگاه‌های امانی: #{export.summary.loaned_total_count}</strong></td>
              </tr>
              <tr class="summary-row">
                <td colspan="#{column_count}"><strong>تعداد کل دستگاه‌های سرقتی: #{export.summary.stolen_total_count}</strong></td>
              </tr>
              <tr class="operational-total">
                <td colspan="#{column_count}"><strong>جمع کل ناوگان (شعب + تعمیرگاه + در انتظار قطعه + امانی + سرقتی): #{export.summary.operational_total}</strong></td>
              </tr>
              <tr class="reference-row">
                <td colspan="#{column_count}">موجودی انبار دستگاه‌های نو: #{export.summary.new_stock_total_count} | تعداد فروش ثبت‌شده: #{export.summary.sold_total_count}</td>
              </tr>
              <tr class="summary-title">
                <td colspan="#{column_count}"><strong>جزئیات دستگاه‌های سرقتی به تفکیک شعبه و نوع</strong></td>
              </tr>
              <tr>
                <td colspan="#{column_count}" style="padding: 0;">
                  <table style="width: 100%; border-collapse: collapse;">
                    <thead><tr><th>شعبه</th><th>نوع دستگاه</th><th>تعداد سرقتی</th></tr></thead>
                    <tbody>#{if stolen_breakdown_rows == "", do: "<tr><td colspan='3'>موردی ثبت نشده است.</td></tr>", else: stolen_breakdown_rows}</tbody>
                  </table>
                </td>
              </tr>
            </tbody>
          </table>
        </body>
      </html>
      """
    ]
    |> IO.iodata_to_binary()
  end

  defp escape_html(value) do
    value
    |> to_string()
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end
end

Beroon.Scripts.ExportAssignedInventoryReport.run()
