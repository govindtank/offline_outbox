import 'dart:async';
import '../models/outbox_request.dart';
import '../storage/outbox_storage.dart';

/// Callback invoked to execute a pending network request over HTTP or REST/GraphQL client.
/// Returns `true` if the server processed the request successfully, or `false` on retryable network failure.
typedef OutboxExecutor = Future<bool> Function(OutboxRequest request);

/// The core engine managing the offline transactional outbox queue, priority processing,
/// exponential backoff retry scheduling, and persistent state sync.
class OfflineOutboxEngine {
  /// Persistent storage adapter.
  final OutboxStorage storage;

  /// Network executor function.
  final OutboxExecutor executor;

  /// Configurable retry policy.
  final RetryPolicy retryPolicy;

  final StreamController<int> _pendingCountController =
      StreamController<int>.broadcast();
  final StreamController<OutboxRequest> _onCompletedController =
      StreamController<OutboxRequest>.broadcast();
  final StreamController<OutboxRequest> _onFailedController =
      StreamController<OutboxRequest>.broadcast();

  bool _isProcessing = false;
  bool _isPaused = false;
  Timer? _autoSyncTimer;

  /// Creates an [OfflineOutboxEngine].
  OfflineOutboxEngine({
    required this.storage,
    required this.executor,
    this.retryPolicy = const RetryPolicy(),
  });

  /// Initializes storage and emits initial queue length.
  Future<void> init() async {
    await storage.init();
    await _updateCount();
  }

  /// Broadcast stream emitting current number of pending items in the queue.
  Stream<int> get pendingCountStream => _pendingCountController.stream;

  /// Broadcast stream emitting requests that succeeded.
  Stream<OutboxRequest> get onCompletedStream => _onCompletedController.stream;

  /// Broadcast stream emitting requests that failed.
  Stream<OutboxRequest> get onFailedStream => _onFailedController.stream;

  /// Whether the queue processor is paused.
  bool get isPaused => _isPaused;

  /// Whether the queue is currently actively processing items.
  bool get isProcessing => _isProcessing;

  /// Enqueues a new [OutboxRequest]. If an item with the same [idempotencyKey] exists, deduplicates.
  Future<void> enqueue(OutboxRequest request) async {
    if (request.idempotencyKey != null && request.idempotencyKey!.isNotEmpty) {
      final existing = await storage.getAll();
      final hasDuplicate =
          existing.any((item) => item.idempotencyKey == request.idempotencyKey);
      if (hasDuplicate) return;
    }

    await storage.save(request);
    await _updateCount();
  }

  /// Processes all pending requests currently eligible for transmission.
  /// Returns the number of successfully delivered requests in this run.
  Future<int> processQueue() async {
    if (_isProcessing || _isPaused) return 0;

    _isProcessing = true;
    int successCount = 0;

    try {
      final List<OutboxRequest> allItems = await storage.getAll();
      final DateTime now = DateTime.now();

      // Filter eligible items
      final List<OutboxRequest> eligible = allItems.where((item) {
        if (item.status == OutboxItemStatus.deadLetter) return false;
        if (item.nextRetryAt != null && item.nextRetryAt!.isAfter(now))
          return false;
        return true;
      }).toList();

      // Sort by Priority (critical > high > normal > low), then by createdAt ascending
      eligible.sort((a, b) {
        final int prioComp = a.priority.index.compareTo(b.priority.index);
        if (prioComp != 0) return prioComp;
        return a.createdAt.compareTo(b.createdAt);
      });

      for (final req in eligible) {
        if (_isPaused) break;

        final updatedReq = req.copyWith(
          status: OutboxItemStatus.inFlight,
          attempts: req.attempts + 1,
        );
        await storage.save(updatedReq);

        bool isSuccess = false;
        String? errorMessage;

        try {
          isSuccess = await executor(updatedReq);
        } catch (e) {
          isSuccess = false;
          errorMessage = e.toString();
        }

        if (isSuccess) {
          await storage.remove(req.id);
          successCount++;
          _onCompletedController
              .add(updatedReq.copyWith(status: OutboxItemStatus.completed));
        } else {
          final int attempts = updatedReq.attempts;
          if (attempts >= retryPolicy.maxAttempts) {
            // Move to dead-letter
            final deadReq = updatedReq.copyWith(
              status: OutboxItemStatus.deadLetter,
              lastError:
                  errorMessage ?? 'Max retry attempts ($attempts) exceeded',
            );
            await storage.save(deadReq);
            _onFailedController.add(deadReq);
          } else {
            // Schedule next exponential backoff retry
            final Duration delay = retryPolicy.computeNextDelay(attempts);
            final failedReq = updatedReq.copyWith(
              status: OutboxItemStatus.failed,
              nextRetryAt: DateTime.now().add(delay),
              lastError: errorMessage ?? 'Network transmission failed',
            );
            await storage.save(failedReq);
            _onFailedController.add(failedReq);
          }
        }
      }
    } finally {
      _isProcessing = false;
      await _updateCount();
    }

    return successCount;
  }

  /// Pauses queue processing (e.g. when app goes into background or device is known offline).
  void pause() {
    _isPaused = true;
  }

  /// Resumes queue processing.
  void resume() {
    _isPaused = false;
  }

  /// Starts a periodic auto-sync timer.
  void startAutoSync({Duration interval = const Duration(seconds: 15)}) {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(interval, (_) => processQueue());
  }

  /// Stops the periodic auto-sync timer.
  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  Future<void> _updateCount() async {
    final items = await storage.getAll();
    final count =
        items.where((i) => i.status != OutboxItemStatus.deadLetter).length;
    if (!_pendingCountController.isClosed) {
      _pendingCountController.add(count);
    }
  }

  /// Disposes all timers and stream controllers.
  Future<void> dispose() async {
    stopAutoSync();
    await _pendingCountController.close();
    await _onCompletedController.close();
    await _onFailedController.close();
  }
}
