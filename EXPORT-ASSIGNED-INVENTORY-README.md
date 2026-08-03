# خروجی موجودی تخصیص‌یافته شعب

این اسکریپت همان اطلاعات خروجی فعلی گزارش ادمین را تولید می‌کند، اما ستون‌های شعب را از آمار شبانه نمی‌خواند.
تعداد هر شعبه مستقیماً از دستگاه‌هایی محاسبه می‌شود که `branch_id` آن‌ها متعلق به همان شعبه است.

## اجرای ساده در PowerShell

از ریشه پروژه اجرا کنید:

```powershell
.\export-assigned-inventory.ps1
```

یا مستقیماً با Mix:

```powershell
mix run priv/scripts/export_assigned_inventory_report.exs
```

برای محیط production:

```powershell
$env:MIX_ENV="prod"
mix run priv/scripts/export_assigned_inventory_report.exs
```

## محل فایل خروجی

فایل در پوشه زیر ساخته می‌شود:

```text
exports/beroon-assigned-inventory-YYYY-MM-DD.xls
```

تاریخ نام فایل شمسی است. گزارش همیشه برای تاریخ امروز بر اساس ساعت تهران ساخته می‌شود.

## منطق شمارش شعب

- منبع شمارش شعب: جدول `scooters` و ستون `branch_id`
- دستگاه‌های تعمیرگاهی، در انتظار قطعه، امانی، سرقتی و از مدار خارج‌شده در ستون شعب دوباره شمرده نمی‌شوند.
- دستگاه حمل‌ونقل بر اساس شعبه مالک (`branch_id`) محاسبه می‌شود.
- سایر ستون‌ها دقیقاً از همان منطق خروجی فعلی `/report-export` استفاده می‌کنند.
