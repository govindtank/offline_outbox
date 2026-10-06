# offline_outbox

<p align="center">
  <a href="https://pub.dev/packages/offline_outbox"><img src="https://img.shields.io/pub/v/offline_outbox.svg?style=flat-square&color=blue" alt="Pub Version"></a>
  <a href="https://pub.dev/packages/offline_outbox/score"><img src="https://img.shields.io/pub/points/offline_outbox?style=flat-square&color=2E8B57&label=pub%20points" alt="Pub Points"></a>
  <a href="https://pub.dev/packages/offline_outbox"><img src="https://img.shields.io/pub/likes/offline_outbox?style=flat-square" alt="Pub Likes"></a>
  <a href="https://github.com/govindtank/offline_outbox/actions"><img src="https://github.com/govindtank/offline_outbox/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-Apache%202.0-blue.svg?style=flat-square" alt="License"></a>
</p>

---

## ⚡ Why offline_outbox?

In mobile development, network connections flicker constantly. Standard in-memory retry libraries fail when the app process is terminated or the phone restarts.

`offline_outbox` provides the **Transactional Outbox Pattern** for Flutter:
1. **Never Lose a Mutation**: When the user places an order, sends a message, or likes a post, the request is written to persistent disk storage *before* network delivery.
2. **Exponential Backoff with Random Jitter**: Failed network requests automatically back off exponentially with randomized jitter to prevent server thundering-herd spikes on reconnect.
3. **Idempotency & Deduplication**: Prevents duplicate charges or double orders by checking unique `idempotencyKey` values before enqueueing.
4. **4-Tier Priority Scheduling**: `OutboxPriority.critical` requests (payments, bookings) are drained before `OutboxPriority.low` requests (analytics, logs).
5. **Storage & HTTP Agnostic**: Works seamlessly with Dio, `package:http`, Hive, SQLite, or the built-in `FileJsonOutboxStorage`.

---

## 📦 Installation

Add `offline_outbox` to your `pubspec.yaml`:

```yaml
dependencies:
  offline_outbox: ^1.1.1
```

Or run:

```bash
flutter pub add offline_outbox
```

---

## 🚀 Quick Start

### 1. Initialize Engine

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:offline_outbox/offline_outbox.dart';

// Create storage (File-based, Hive, or InMemory)
final storage = FileJsonOutboxStorage(File('/path/to/outbox.json'));

final outbox = OfflineOutboxEngine(
  storage: storage,
  retryPolicy: const RetryPolicy(
    maxAttempts: 5,
    initialDelay: Duration(seconds: 2),
    maxDelay: Duration(minutes: 2),
    backoffMultiplier: 2.0,
    enableJitter: true,
  ),
  executor: (request) async {
    // Perform your actual HTTP / Dio request here:
    // final response = await dio.request(request.endpoint, data: request.payload, ...);
    // return response.statusCode == 200;
    return true; // Return true on success, false/throw on retryable error
  },
);

await outbox.init();
```

---

### 2. Enqueue an Offline Request

```dart
await outbox.enqueue(
  OutboxRequest(
    id: 'req_${DateTime.now().millisecondsSinceEpoch}',
    endpoint: '/api/v1/orders',
    method: 'POST',
    payload: {'item_id': 101, 'quantity': 2},
    priority: OutboxPriority.critical,
    idempotencyKey: 'order_uuid_987654',
  ),
);
```

---

### 3. Process & Drain Queue

```dart
// Drain the queue manually (e.g. on connectivity reconnect):
final int deliveredCount = await outbox.processQueue();

// Or enable background periodic auto-sync:
outbox.startAutoSync(interval: const Duration(seconds: 15));
```

---

### 4. Real-time Status Stream

```dart
// Listen to live pending items count:
outbox.pendingCountStream.listen((count) {
  print('Pending outbox items: $count');
});

// Listen to delivered requests:
outbox.onCompletedStream.listen((req) {
  print('Delivered: ${req.endpoint}');
});
```

---

## 🛠️ API Reference

### `OutboxRequest` Parameters

| Field | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `id` | `String` | **Required** | Unique item identifier. |
| `endpoint` | `String` | **Required** | Target API URL or path. |
| `method` | `String` | `'POST'` | HTTP method (`GET`, `POST`, `PUT`, `DELETE`, `PATCH`). |
| `payload` | `dynamic` | `null` | JSON body payload or request data. |
| `headers` | `Map<String, String>?` | `null` | HTTP headers. |
| `idempotencyKey` | `String?` | `null` | Key to prevent duplicate requests. |
| `priority` | `OutboxPriority` | `normal` | `critical`, `high`, `normal`, or `low`. |

---

## 💖 Support the Project

If you find this project useful, consider supporting its active maintenance and future development:

<p align="left">
  <a href="https://buymeacoffee.com/govindtanko"><img src="https://img.shields.io/badge/Buy%20Me%20A%20Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black" alt="Buy Me A Coffee" /></a>
  <a href="https://github.com/sponsors/govindtank"><img src="https://img.shields.io/badge/GitHub%20Sponsors-EA4AAA?style=for-the-badge&logo=github&logoColor=white" alt="GitHub Sponsors" /></a>
  <a href="https://www.patreon.com/govindtank"><img src="https://img.shields.io/badge/Patreon-F96854?style=for-the-badge&logo=patreon&logoColor=white" alt="Patreon" /></a>
</p>

---

## 📄 License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

*Maintained with ❤️ by [Govind Tank](https://github.com/govindtank).*
