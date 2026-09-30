/// Resilient offline-first transactional outbox and retry queue for Dart and Flutter.
///
/// Provides disk persistence, exponential backoff with jitter, priority scheduling,
/// idempotency deduplication, and stream status triggers.
///
/// Implementation by Govind Tank.
library offline_outbox;

export 'src/models/outbox_request.dart';
export 'src/storage/outbox_storage.dart';
export 'src/engine/offline_outbox_engine.dart';
export 'src/storage/outbox_storage.dart' show CallbackOutboxStorage;
