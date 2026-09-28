import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_outbox/offline_outbox.dart';

void main() {
  group('OutboxStorage Unit Tests', () {
    test('InMemoryOutboxStorage CRUD lifecycle', () async {
      final storage = InMemoryOutboxStorage();
      await storage.init();

      final req1 = OutboxRequest(id: '1', endpoint: '/a');
      final req2 = OutboxRequest(id: '2', endpoint: '/b');

      await storage.save(req1);
      await storage.save(req2);

      var all = await storage.getAll();
      expect(all.length, 2);

      final fetched = await storage.getById('1');
      expect(fetched?.endpoint, '/a');

      await storage.remove('1');
      all = await storage.getAll();
      expect(all.length, 1);
      expect(all.first.id, '2');

      await storage.clear();
      all = await storage.getAll();
      expect(all.isEmpty, isTrue);
    });

    test('FileJsonOutboxStorage persists to temporary file', () async {
      final tempDir = await Directory.systemTemp.createTemp('outbox_test_');
      final file = File('${tempDir.path}/outbox.json');
      final storage = FileJsonOutboxStorage(file);
      await storage.init();

      final req =
          OutboxRequest(id: 'file_1', endpoint: '/sync', payload: {'k': 'v'});
      await storage.save(req);

      // Verify file written
      expect(await file.exists(), isTrue);

      // Create new storage instance pointing to same file
      final storage2 = FileJsonOutboxStorage(file);
      await storage2.init();
      final loaded = await storage2.getAll();
      expect(loaded.length, 1);
      expect(loaded.first.id, 'file_1');
      expect(loaded.first.payload['k'], 'v');

      // Cleanup
      await tempDir.delete(recursive: true);
    });
  });
}
