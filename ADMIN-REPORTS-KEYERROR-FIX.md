# Admin reports KeyError fix

The `admin_reports/2` action now assigns:

- `branches`
- `report_date`
- `branch_report_statuses`

This prevents `KeyError: key :branch_report_statuses not found`, including when an older compiled version of the template is still present during development code reload.

The status section remains in `admin_evening_report_branches.html.heex`, as intended.
