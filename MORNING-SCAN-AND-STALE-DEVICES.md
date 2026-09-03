# Morning scan and stale devices update

- Added scanned/unscanned counters to manager morning checklist.
- Both counters expand to show plate and QR/barcode value for each device.
- Admin branch checklist reports continue to expose the unscanned device list.
- Added `/admin/unscanned-devices` for devices whose latest morning/evening scan is older than 48 hours (or never scanned), with current status and last scan time.
- Replaced the final admin dashboard tile with the new stale unscanned devices page.
- Removed checkbox styling classes from native checkboxes and the shared checkbox component.
