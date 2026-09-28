import 'package:flutter_test/flutter_test.dart';
import 'package:offline_outbox/offline_outbox.dart';

void main() {
  group('OfflineOutboxEngine Unit Tests', () {
    test('Deduplicates enqueue with identical idempotencyKey', () async {
      final storage = InMemoryOutboxStorage();
      final engine = OfflineOutboxEngine(
        storage: storage,
        executor: (req) async => true,
      );
      await engine.init();

      final req1 =
          OutboxRequest(id: '1', endpoint: '/order', idempotencyKey: 'idem_A');
      final req2 =
          OutboxRequest(id: '2', endpoint: '/order', idempotencyKey: 'idem_A');

      await engine.enqueue(req1);
      await engine.enqueue(req2);

      final stored = await storage.getAll();
      expect(stored.length, 1);
      expect(stored.first.id, '1');

      await engine.dispose();
    });

    test('Processes critical priority requests before low priority', () async {
      final storage = InMemoryOutboxStorage();
      final List<String> executionOrder = [];

      final engine = OfflineOutboxEngine(
        storage: storage,
        executor: (req) async {
          executionOrder.add(req.id);
          return true;
        },
      );
      await engine.init();

      // Enqueue Low first, then Critical
      await engine.enqueue(OutboxRequest(
          id: 'low_req', endpoint: '/analytics', priority: OutboxPriority.low));
      await engine.enqueue(OutboxRequest(
          id: 'crit_req',
          endpoint: '/payment',
          priority: OutboxPriority.critical));

      final count = await engine.processQueue();
      expect(count, 2);
      expect(executionOrder, ['crit_req', 'low_req']);

      final remaining = await storage.getAll();
      expect(remaining.isEmpty, isTrue);

      await engine.dispose();
    });

    test(
        'Retries with exponential backoff on failure and marks dead letter after max attempts',
        () async {
      final storage = InMemoryOutboxStorage();
      int callCount = 0;

      final engine = OfflineOutboxEngine(
        storage: storage,
        retryPolicy: const RetryPolicy(
            maxAttempts: 2, initialDelay: Duration(milliseconds: 50)),
        executor: (req) async {
          callCount++;
          return false; // Always fail
        },
      );
      await engine.init();

      await engine.enqueue(OutboxRequest(id: 'fail_req', endpoint: '/fail'));

      // 1st attempt
      await engine.processQueue();
      expect(callCount, 1);
      var items = await storage.getAll();
      expect(items.first.attempts, 1);
      expect(items.first.status, OutboxItemStatus.failed);
      expect(items.first.nextRetryAt, isNotNull);

      // Wait for backoff
      await Future<void>.delayed(const Duration(milliseconds: 70));

      // 2nd attempt -> should transition to dead letter
      await engine.processQueue();
      expect(callCount, 2);
      items = await storage.getAll();
      expect(items.first.attempts, 2);
      expect(items.first.status, OutboxItemStatus.deadLetter);

      await engine.dispose();
    });
  });
}
