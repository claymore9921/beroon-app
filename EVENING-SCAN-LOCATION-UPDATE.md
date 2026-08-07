# Evening scan and current-location update

Changes in this build:

- Evening manual plate input uses a numeric mobile keyboard and validates 4-digit plates.
- After "manual add", focus returns to the plate input automatically.
- Final button is renamed to "پایان آمارگیری" and requires confirmation before submit.
- Every accepted evening scan updates `current_branch_id` immediately and sets the scooter active.
- A foreign scooter in active transport is rejected from a non-owner branch.
- If a scooter already exists in another branch's finalized evening count for the same operational date, finalizing the new branch removes it from the previous count and recalculates the previous totals.
- Foreign-but-non-transport scooters can move between branches and are counted at the latest scanned branch while keeping their original `branch_id` ownership.
- Morning checklist submissions refresh the scooter current location to the owner branch.
- Sending/accepting/repairing/waiting/discharging a scooter keeps its current location at the workshop; receiving it back updates location to the owner branch.
- Admin device-location result continues to show device type, owner branch, and current branch.

No new database migration is required.
