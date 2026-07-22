# Admin reports hotfix

- Replaced `admin_reports.html.heex` with the clean two-column admin menu. It no longer reads `@location_alerts` or any moved dashboard assigns.
- `admin_reports/2` only provides the assigns required by the clean dashboard.
- Fixed the new-device inventory sales link to `/admin/new-device-sales`.
- Removed unused private helper `admin_scooter_counts/0`.

On Windows, replace the whole project or at minimum these files, then clear `_build/dev` before compiling.
