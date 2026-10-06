## 1.1.2

* docs: update centered vector badges and documentation.

## 1.1.1

* Added `CallbackOutboxStorage` for custom key-value databases and SharedPreferences persistence.
* Verified CI/CD workflows.

## 1.1.0

* Converted to pure Dart package (zero Flutter SDK dependency).
* Added per-request `requestTimeout` in `RetryPolicy` to prevent hung executor locks.
* Added `enqueueAll()` batch request insertion.
* Added dead-letter queue management APIs: `getDeadLetterRequests()`, `retryDeadLetter()`, and `clearDeadLetters()`.
* Added `onDeadLetterStream` for real-time monitoring of failed items.
* Fixed `copyWith` null-safety bug allowing explicit reset of nullable fields.
* Added explicit `platforms` declaration (Android, iOS, macOS, Windows, Linux).

## 1.0.0

* Initial stable release of `offline_outbox`.
* Implemented transactional `OfflineOutboxEngine` with priority scheduling (`critical` to `low`).
* Implemented `RetryPolicy` with exponential backoff and randomized jitter calculation.
* Added `OutboxStorage` abstraction with built-in `InMemoryOutboxStorage` and `FileJsonOutboxStorage`.
* Added idempotency key tracking and queue deduplication.
* Real-time stream controllers for pending counts, completion events, and failure alerts.
* Interactive example app simulating online/offline state, manual sync, and event logging.
* 100% test coverage and zero pub.dev warnings.
