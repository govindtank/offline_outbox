import 'dart:io';
import 'package:test/test.dart';
import 'package:offline_outbox/offline_outbox.dart';

void main() {
  group('OutboxStorage Unit Tests', () {
    test('InMemoryOutboxStorage CRUD lifecycle', () async {
      final storage = InMemoryOutboxStorage();
      await storage.init();

      final req1 = OutboxRequest(id: 'r1', endpoint: '/api/v1');
      final req2 = OutboxRequest(id: 'r2', endpoint: '/api/v2');

      await storage.save(req1);
      await storage.save(req2);

      expect(await storage.getAll(), hasLength(2));
      expect((await storage.getById('r1'))?.endpoint, '/api/v1');

      await storage.remove('r1');
      expect(await storage.getAll(), hasLength(1));
      expect(await storage.getById('r1'), isNull);

      await storage.clear();
      expect(await storage.getAll(), isEmpty);
    });

    test('FileJsonOutboxStorage persists to disk', () async {
      final tempDir = await Directory.systemTemp.createTemp('outbox_test_');
      final file = File('${tempDir.path}/outbox.json');

      final storage1 = FileJsonOutboxStorage(file);
      await storage1.init();

      final req = OutboxRequest(
        id: 'persistent_1',
        endpoint: '/checkout',
        payload: {'amount': 99.9},
      );
      await storage1.save(req);

      // Re-open with new storage instance to verify file hydration
      final storage2 = FileJsonOutboxStorage(file);
      await storage2.init();

      final retrieved = await storage2.getById('persistent_1');
      expect(retrieved, isNotNull);
      expect(retrieved?.payload['amount'], 99.9);

      await tempDir.delete(recursive: true);
    });
  });
}
