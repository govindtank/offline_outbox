import 'dart:async';
import 'package:test/test.dart';
import 'package:offline_outbox/offline_outbox.dart';

void main() {
  group('OfflineOutboxEngine Unit Tests', () {
    late InMemoryOutboxStorage storage;

    setUp(() {
      storage = InMemoryOutboxStorage();
    });

    test('Deduplicates enqueue with identical idempotencyKey', () async {
      final engine = OfflineOutboxEngine(
        storage: storage,
        executor: (_) async => true,
      );
      await engine.init();

      final req1 = OutboxRequest(
        id: '1',
        endpoint: '/pay',
        idempotencyKey: 'pay_txn_123',
      );
      final req2 = OutboxRequest(
        id: '2',
        endpoint: '/pay',
        idempotencyKey: 'pay_txn_123', // duplicate
      );

      await engine.enqueue(req1);
      await engine.enqueue(req2);

      final all = await storage.getAll();
      expect(all.length, 1);
      expect(all.first.id, '1');
    });

    test('Batch enqueue enqueues all items', () async {
      final engine = OfflineOutboxEngine(
        storage: storage,
        executor: (_) async => true,
      );
      await engine.init();

      final requests = [
        OutboxRequest(id: 'b1', endpoint: '/e1'),
        OutboxRequest(id: 'b2', endpoint: '/e2'),
        OutboxRequest(id: 'b3', endpoint: '/e3'),
      ];

      await engine.enqueueAll(requests);
      expect(await storage.getAll(), hasLength(3));
    });

    test('Processes critical priority requests before low priority', () async {
      final List<String> executionOrder = [];
      final engine = OfflineOutboxEngine(
        storage: storage,
        executor: (req) async {
          executionOrder.add(req.id);
          return true;
        },
      );
      await engine.init();

      await engine.enqueue(OutboxRequest(
        id: 'low_req',
        endpoint: '/analytics',
        priority: OutboxPriority.low,
      ));
      await engine.enqueue(OutboxRequest(
        id: 'crit_req',
        endpoint: '/charge',
        priority: OutboxPriority.critical,
      ));

      final processed = await engine.processQueue();
      expect(processed, 2);
      expect(executionOrder, ['crit_req', 'low_req']);
    });

    test('Retries with exponential backoff on failure and marks dead letter after max attempts',
        () async {
      int attemptsCount = 0;
      final engine = OfflineOutboxEngine(
        storage: storage,
        retryPolicy: const RetryPolicy(
          maxAttempts: 2,
          initialDelay: Duration(milliseconds: 50),
          enableJitter: false,
        ),
        executor: (req) async {
          attemptsCount++;
          return false; // Fail
        },
      );
      await engine.init();

      final req = OutboxRequest(id: 'failing_1', endpoint: '/webhook');
      await engine.enqueue(req);

      // Attempt 1: Should fail and schedule retry
      await engine.processQueue();
      expect(attemptsCount, 1);
      var item = await storage.getById('failing_1');
      expect(item?.status, OutboxItemStatus.failed);
      expect(item?.attempts, 1);

      // Wait for backoff
      await Future.delayed(const Duration(milliseconds: 60));

      // Attempt 2: Max attempts reached -> Dead Letter
      await engine.processQueue();
      expect(attemptsCount, 2);
      item = await storage.getById('failing_1');
      expect(item?.status, OutboxItemStatus.deadLetter);

      // Verify dead letter retrieval and retry
      final deadLetters = await engine.getDeadLetterRequests();
      expect(deadLetters, hasLength(1));

      final retried = await engine.retryDeadLetter('failing_1');
      expect(retried, isTrue);
      item = await storage.getById('failing_1');
      expect(item?.status, OutboxItemStatus.pending);
      expect(item?.attempts, 0);

      // Clear dead letters
      await engine.clearDeadLetters();
      expect(await engine.getDeadLetterRequests(), isEmpty);
    });

    test('Request timeout triggers failure', () async {
      final engine = OfflineOutboxEngine(
        storage: storage,
        retryPolicy: const RetryPolicy(
          maxAttempts: 1,
          requestTimeout: Duration(milliseconds: 50),
        ),
        executor: (req) async {
          await Future.delayed(const Duration(milliseconds: 200)); // Hanged request
          return true;
        },
      );
      await engine.init();

      await engine.enqueue(OutboxRequest(id: 'hang_1', endpoint: '/slow'));
      await engine.processQueue();

      final item = await storage.getById('hang_1');
      expect(item?.status, OutboxItemStatus.deadLetter);
      expect(item?.lastError, contains('timed out'));
    });
  });
}
