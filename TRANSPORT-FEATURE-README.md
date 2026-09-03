# سیستم حمل‌ونقل دستگاه

## اجرای دیتابیس

```bash
mix ecto.migrate
```

Migration جدید:

`priv/repo/migrations/20260721120000_create_scooter_transports_and_current_locations.exs`

## مدل اطلاعات

- `scooters.branch_id`: شعبه مالک دستگاه؛ هرگز با حمل‌ونقل تغییر نمی‌کند.
- `scooters.current_branch_id`: محل فعلی دستگاه.
- `scooter_transports`: تاریخچه بارنامه‌ها.

ثبت بارنامه بلافاصله `current_branch_id` را به مقصد تغییر می‌دهد و نیازی به تأیید تحویل ندارد.
اسکن آمار شبانه نیز محل فعلی تمام دستگاه‌های اسکن‌شده را به شعبه ثبت‌کننده اصلاح می‌کند.

## مسیرهای جدید

- مدیر شعبه: `/manager/transports`
- ادمین: `/admin/device-locations`

شعبه با نام یا کد شامل `باهنر` / `bahonar` به‌عنوان مقصد پیش‌فرض انتخاب می‌شود.
