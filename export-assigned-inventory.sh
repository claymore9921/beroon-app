#!/usr/bin/env bash
set -euo pipefail

export MIX_ENV="${MIX_ENV:-prod}"
echo "در حال ساخت گزارش همه دستگاه‌های تخصیص‌یافته به شعب با هر وضعیت..."
mix run priv/scripts/export_assigned_inventory_report.exs
echo "فایل در پوشه exports پروژه ساخته شد."
