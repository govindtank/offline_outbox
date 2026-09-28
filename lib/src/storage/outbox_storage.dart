import 'dart:convert';
import 'dart:io';
import '../models/outbox_request.dart';

/// Pluggable storage abstraction for persisting offline outbox requests.
abstract class OutboxStorage {
  /// Initializes storage system (e.g. opens file or creates tables).
  Future<void> init();

  /// Saves or updates an [OutboxRequest].
  Future<void> save(OutboxRequest request);

  /// Removes an [OutboxRequest] from storage by ID.
  Future<void> remove(String id);

  /// Retrieves all stored requests.
  Future<List<OutboxRequest>> getAll();

  /// Retrieves a specific request by ID.
  Future<OutboxRequest?> getById(String id);

  /// Clears all entries from storage.
  Future<void> clear();
}

/// In-memory storage adapter for testing and lightweight sessions.
class InMemoryOutboxStorage implements OutboxStorage {
  final Map<String, OutboxRequest> _items = {};

  @override
  Future<void> init() async {}

  @override
  Future<void> save(OutboxRequest request) async {
    _items[request.id] = request;
  }

  @override
  Future<void> remove(String id) async {
    _items.remove(id);
  }

  @override
  Future<List<OutboxRequest>> getAll() async {
    return _items.values.toList();
  }

  @override
  Future<OutboxRequest?> getById(String id) async {
    return _items[id];
  }

  @override
  Future<void> clear() async {
    _items.clear();
  }
}

/// File-based JSON storage implementation (zero external dependencies).
class FileJsonOutboxStorage implements OutboxStorage {
  final File file;
  final Map<String, OutboxRequest> _cache = {};

  /// Creates a [FileJsonOutboxStorage] using the specified [file].
  FileJsonOutboxStorage(this.file);

  @override
  Future<void> init() async {
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final dynamic decoded = jsonDecode(content);
          if (decoded is List) {
            _cache.clear();
            for (final item in decoded) {
              if (item is Map<String, dynamic>) {
                final req = OutboxRequest.fromJson(item);
                _cache[req.id] = req;
              }
            }
          }
        }
      } catch (_) {
        // Corrupted file -> start fresh
        _cache.clear();
      }
    } else {
      await file.create(recursive: true);
    }
  }

  Future<void> _flush() async {
    final list = _cache.values.map((e) => e.toJson()).toList();
    await file.writeAsString(jsonEncode(list), flush: true);
  }

  @override
  Future<void> save(OutboxRequest request) async {
    _cache[request.id] = request;
    await _flush();
  }

  @override
  Future<void> remove(String id) async {
    if (_cache.containsKey(id)) {
      _cache.remove(id);
      await _flush();
    }
  }

  @override
  Future<List<OutboxRequest>> getAll() async {
    return _cache.values.toList();
  }

  @override
  Future<OutboxRequest?> getById(String id) async {
    return _cache[id];
  }

  @override
  Future<void> clear() async {
    _cache.clear();
    await _flush();
  }
}
