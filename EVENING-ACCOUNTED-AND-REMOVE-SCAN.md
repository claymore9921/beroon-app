# Evening report/accounting fixes

- Branch evening audit now includes scooters owned by the branch that are already in explained operational statuses (damaged/needs service, awaiting repair, repairing, ready for pickup, waiting for part, loaned, stolen, out of service, transport) in **accounted** even when those scooters were excluded from the original expected-evening snapshot.
- The manager evening scan list now has a per-plate **حذف** button. Removing a plate updates the visible count, in-memory duplicate guard and localStorage draft, then returns focus to the plate input.
- No database migration is required.
