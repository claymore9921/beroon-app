$ErrorActionPreference = "Stop"

Write-Host "در حال ساخت گزارش موجودی تخصیص‌یافته شعب..." -ForegroundColor Cyan
mix run priv/scripts/export_assigned_inventory_report.exs

if ($LASTEXITCODE -ne 0) {
  throw "ساخت گزارش با خطا مواجه شد."
}

Write-Host "فایل در پوشه exports پروژه ساخته شد." -ForegroundColor Green
