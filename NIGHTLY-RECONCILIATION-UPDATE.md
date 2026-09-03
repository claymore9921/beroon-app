# Nightly reconciliation update

- Manager repair search/submit now uses `current_branch_id`, so a host branch can send a guest scooter to the workshop without changing permanent ownership (`branch_id`).
- Expected evening scooters are based on `current_branch_id`, so the branch physically holding a scooter is responsible for that night's scan.
- Transport/workshop/waiting-part/loaned/stolen/out-of-service scooters are excluded from branch expected counts.
- Admin evening audit splits absent scooters into:
  - accounted (workshop, waiting part, loaned, stolen, transport, out of service, or known current location elsewhere)
  - needs review (no scan/move/explained status)
- Admin branch cards show the needs-review count for the latest completed cycle.
- Daily Excel export has a `نیاز به بررسی` column. It is informational and is intentionally excluded from the total so unexplained loss reduces the control total and is visible as a discrepancy.
