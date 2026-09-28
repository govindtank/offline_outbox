## 1.0.0

* Initial stable release of `offline_outbox`.
* Implemented transactional `OfflineOutboxEngine` with priority scheduling (`critical` to `low`).
* Implemented `RetryPolicy` with exponential backoff and randomized jitter calculation.
* Added `OutboxStorage` abstraction with built-in `InMemoryOutboxStorage` and `FileJsonOutboxStorage`.
* Added idempotency key tracking and queue deduplication.
* Real-time stream controllers for pending counts, completion events, and failure alerts.
* Interactive example app simulating online/offline state, manual sync, and event logging.
* 100% test coverage and zero pub.dev warnings.
