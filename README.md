# offline_outbox

[![Pub Version](https://img.shields.io/pub/v/offline_outbox.svg?style=flat-square&color=blue)](https://pub.dev/packages/offline_outbox)
[![Pub Points](https://img.shields.io/pub/points/offline_outbox?style=flat-square&color=2E8B57&label=pub%20points)](https://pub.dev/packages/offline_outbox/score)
[![Pub Likes](https://img.shields.io/pub/likes/offline_outbox?style=flat-square)](https://pub.dev/packages/offline_outbox)
[![CI](https://github.com/govindtank/offline_outbox/actions/workflows/ci.yml/badge.svg)](https://github.com/govindtank/offline_outbox/actions)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg?style=flat-square)](LICENSE)

A resilient, offline-first transactional outbox and retry queue for Flutter and Dart with **persistent disk storage**, **exponential backoff with jitter**, **priority scheduling**, and **idempotency deduplication**.

<p align="center">
  <img src="https://raw.githubusercontent.com/govindtank/offline_outbox/main/screenshot.svg" width="750" alt="offline_outbox demo"/>
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

## 👨💻 Author & Maintainer

Developed and maintained by **Govind Tank**.

Issues, feedback, and pull requests are welcomed on [GitHub](https://github.com/govindtank/offline_outbox)!

---

## 🌐 Ecosystem & Related Packages

Explore complementary production-grade libraries built for high-performance Flutter & Dart development:

| Package | Description | Version |
| :--- | :--- | :--- |
| **[`ambient_backdrop_glow`](https://pub.dev/packages/ambient_backdrop_glow)** | Dynamic ambient background glow and fluid animated mesh gradients from image artwork with OKLab color blending for Flutter. | `^1.1.2` |
| **[`country_mobile_validator`](https://pub.dev/packages/country_mobile_validator)** | Validate mobile numbers per country using real length ranges (8-10, 10-11 digits), mobile-only detection, and a country_code_picker-friendly API. | `^0.2.1` |
| **[`cron_schedule`](https://pub.dev/packages/cron_schedule)** | Lightweight, pure-Dart cron parser, next-occurrence predictor, human-readable translator, and fluent schedule builder for Dart and Flutter. | `^1.1.1` |
| **[`currency_field_formatter`](https://pub.dev/packages/currency_field_formatter)** | Bulletproof Flutter currency TextInputFormatter with exact cursor tracking, backspace handling, Indian Lakhs/Crores, and ISO 4217 presets. | `^1.1.1` |
| **[`flutter_whisper`](https://pub.dev/packages/flutter_whisper)** | On-device speech-to-text transcription using whisper.cpp. Automatic model download, streaming segment results, Android support. | `^0.2.1` |
| **[`quote_painter`](https://pub.dev/packages/quote_painter)** | Flutter package for rendering styled text on image/video canvas with gradient fill, stroke, shadow, decorative quotation marks, line badges, and themes. | `^0.2.4` |
| **[`scratch_reveal`](https://pub.dev/packages/scratch_reveal)** | High-performance GPU-accelerated scratch card and scratch-to-reveal canvas widget for Flutter with sub-millisecond bitmask progress tracking. | `^1.1.1` |
| **[`segmented_ring_painter`](https://pub.dev/packages/segmented_ring_painter)** | High-performance segmented circular progress and concentric activity ring widget for Flutter with gradient arcs, rounded caps, gap math, and tap hit-testing. | `^1.1.2` |
| **[`waveform_pro`](https://pub.dev/packages/waveform_pro)** | Production-quality Flutter waveform widget with GPU-accelerated rendering, discrete bars, curved splines, dual-color progress, zoom, markers, and audio peak extraction. | `^1.1.4` |

---

## 📄 License

This package is licensed under the [Apache-2.0 License](LICENSE).
