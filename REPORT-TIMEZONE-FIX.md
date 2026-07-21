# Report timezone and evening status fix

- Daily report dates now use Iran local date (UTC+03:30) through `Beroon.Reports.iran_today/1`.
- Morning checklist `checked_on` uses Iran date.
- Evening count `counted_on` uses Iran date, including submissions after midnight.
- Admin daily report/checklist defaults use Iran date.
- Evening submission/status window increased from 12 hours to 16 hours, covering reports submitted from 18:00 the previous day when reviewed at 10:00 the next morning.
