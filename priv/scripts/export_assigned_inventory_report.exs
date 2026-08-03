defmodule Beroon.Scripts.ExportAssignedInventoryReport do
  @moduledoc false

  import Ecto.Query, warn: false

  alias Beroon.Fleet.Scooter
  alias Beroon.Repo
  alias Beroon.Reports

  def run do
    date = Reports.iran_today()

    export =
      date
      |> Reports.evening_inventory_export()
      |> replace_evening_counts_with_all_assigned_counts()

    output_dir = Path.expand("exports", File.cwd!())
    File.mkdir_p!(output_dir)

    persian_date = Beroon.Calendar.persian_numeric_date(date)
    safe_date = String.replace(persian_date, "/", "-")
    output_path = Path.join(output_dir, "beroon-all-assigned-inventory-#{safe_date}.xls")

    File.write!(output_path, render_xls(export))

    IO.puts("\nگزارش با موفقیت ساخته شد:")
    IO.puts(output_path)
    IO.puts("تاریخ گزارش: #{persian_date}")
    IO.puts("جمع همه دستگاه‌های تخصیص‌یافته به شعب با هر وضعیت: #{export.totals.branches_total_count}\n")
  end

  # ستون هر شعبه از خود جدول scooters و branch_id ساخته می‌شود.
  # هیچ فیلتری بر اساس status اعمال نمی‌شود؛ بنابراین دستگاه فعال، خراب،
  # تعمیرگاهی، در انتظار قطعه، آماده تحویل، امانی، سرقتی و ... همگی
  # زیر شعبه مالک خود شمرده می‌شوند.
  defp replace_evening_counts_with_all_assigned_counts(export) do
    assigned_counts = assigned_counts_by_device_type_and_branch()

    rows =
      Enum.map(export.rows, fn row ->
        branch_counts =
          Map.new(export.branches, fn branch ->
            count = Map.get(assigned_counts, {row.device_type.id, branch.id}, 0)
            {branch.id, count}
          end)

        assigned_total_count = Enum.sum(Map.values(branch_counts))

        row
        |> Map.put(:branch_counts, branch_counts)
        |> Map.put(:branches_total_count, assigned_total_count)
        # این مقدار فقط برای سازگاری با ساختار داده خروجی اصلی نگه داشته می‌شود.
        |> Map.put(:operational_total_count, assigned_total_count)
      end)

    branch_totals =
      Map.new(export.branches, fn branch ->
        total =
          Enum.reduce(rows, 0, fn row, acc ->
            acc + Map.get(row.branch_counts, branch.id, 0)
          end)

        {branch.id, total}
      end)

    assigned_total_count = Enum.sum(Map.values(branch_totals))

    totals =
      export.totals
      |> Map.put(:branch_counts, branch_totals)
      |> Map.put(:branches_total_count, assigned_total_count)
      |> Map.put(:operational_total_count, assigned_total_count)

    summary =
      export.summary
      |> Map.put(:branch_evening_total_count, assigned_total_count)
      |> Map.put(:operational_total, assigned_total_count)

    export
    |> Map.put(:rows, rows)
    |> Map.put(:totals, totals)
    |> Map.put(:summary, summary)
    |> Map.put(:grand_total, assigned_total_count)
  end

  defp assigned_counts_by_device_type_and_branch do
    Scooter
    |> where([s], not is_nil(s.branch_id) and not is_nil(s.device_type_id))
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
        "<th>جمع کل دستگاه‌های تخصیص‌یافته</th>",
        "<th>در انتظار قطعه (از مجموع تخصیص‌یافته)</th>",
        "<th>امانی (از مجموع تخصیص‌یافته)</th>",
        "<th>سرقتی</th>",
        "<th>انبار دستگاه‌های نو</th>",
        "<th>فروش‌رفته</th>"
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
          ~s(<td class="assigned-total"><strong>#{row.branches_total_count}</strong></td>),
          "<td>#{row.waiting_for_part_count}</td>",
          "<td>#{row.loaned_count}</td>",
          "<td>#{row.stolen_count}</td>",
          "<td>#{row.new_stock_count}</td>",
          "<td>#{row.sold_count}</td>",
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
      "<td><strong>#{export.totals.waiting_for_part_count}</strong></td>",
      "<td><strong>#{export.totals.loaned_count}</strong></td>",
      "<td><strong>#{export.totals.stolen_count}</strong></td>",
      "<td><strong>#{export.totals.new_stock_count}</strong></td>",
      "<td><strong>#{export.totals.sold_count}</strong></td>",
      "</tr>"
    ]

    column_count = length(export.branches) + 7

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
            .assigned-total { background: #eef7ff; }
            .total-row td { background: #e9f7f5; border-top: 3px solid #287f78; }
            .summary-title td { background: #dfe9f7; font-size: 16px; border-top: 4px solid #365f91; text-align: right; }
            .summary-row td { background: #f7f7f7; text-align: right; }
            .grand-total td { background: #dff4df; font-size: 17px; border-top: 4px solid #2d7a2d; text-align: right; }
            .reference-row td { background: #f2f2f2; color: #444; text-align: right; }
            .warning-row td { background: #fff8e8; color: #5b4700; text-align: right; }
          </style>
        </head>
        <body>
          <h3>گزارش همه دستگاه‌های تخصیص‌یافته به شعب - #{escape_html(Beroon.Calendar.persian_date(export.date))}</h3>
          <p>
            ستون هر شعبه مستقیماً از <strong>branch_id</strong> دستگاه‌ها محاسبه شده است.
            وضعیت دستگاه در شمارش تأثیری ندارد و دستگاه‌های فعال، خراب، تعمیرگاهی، در انتظار قطعه،
            آماده تحویل، امانی، سرقتی و سایر وضعیت‌ها همگی زیر شعبه مالک خود شمرده می‌شوند.
          </p>
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
              <tr class="grand-total">
                <td colspan="#{column_count}"><strong>جمع کل همه دستگاه‌های تخصیص‌یافته به تمام شعب با هر وضعیت: #{export.totals.branches_total_count}</strong></td>
              </tr>
              <tr class="warning-row">
                <td colspan="#{column_count}">
                  ستون‌های «در انتظار قطعه»، «امانی» و دستگاه‌های سرقتی دارای پلاک، اطلاعات تکمیلی وضعیت هستند
                  و ممکن است بخشی از جمع دستگاه‌های تخصیص‌یافته باشند؛ بنابراین دوباره به جمع کل اضافه نشده‌اند.
                </td>
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
