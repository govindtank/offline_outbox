import 'package:flutter_test/flutter_test.dart';
import 'package:offline_outbox/offline_outbox.dart';

void main() {
  group('OutboxRequest & RetryPolicy Unit Tests', () {
    test('JSON serialization round-trip', () {
      final req = OutboxRequest(
        id: 'req_123',
        endpoint: '/api/v1/orders',
        method: 'POST',
        payload: {'item_id': 42, 'qty': 2},
        headers: {'Authorization': 'Bearer test'},
        idempotencyKey: 'idem_456',
        priority: OutboxPriority.critical,
        attempts: 1,
        status: OutboxItemStatus.pending,
      );

      final json = req.toJson();
      final recovered = OutboxRequest.fromJson(json);

      expect(recovered.id, 'req_123');
      expect(recovered.endpoint, '/api/v1/orders');
      expect(recovered.method, 'POST');
      expect(recovered.payload['item_id'], 42);
      expect(recovered.headers?['Authorization'], 'Bearer test');
      expect(recovered.idempotencyKey, 'idem_456');
      expect(recovered.priority, OutboxPriority.critical);
      expect(recovered.attempts, 1);
    });

    test('RetryPolicy exponential backoff delay growth', () {
      const policy = RetryPolicy(
        initialDelay: Duration(seconds: 2),
        backoffMultiplier: 2.0,
        enableJitter: false, // Deterministic for test
      );

      expect(policy.computeNextDelay(1), const Duration(seconds: 2));
      expect(policy.computeNextDelay(2), const Duration(seconds: 4));
      expect(policy.computeNextDelay(3), const Duration(seconds: 8));
      expect(policy.computeNextDelay(4), const Duration(seconds: 16));
    });
  });
}
