import 'dart:math' as math;

/// Priority level for queued offline outbox requests.
enum OutboxPriority {
  /// Highest priority (e.g. payment transactions, order submissions, chat messages).
  critical,

  /// High priority user actions (e.g. profile updates, settings changes).
  high,

  /// Normal background sync items.
  normal,

  /// Low priority telemetry and analytics.
  low,
}

/// Lifecycle status of an item in the outbox queue.
enum OutboxItemStatus {
  /// Queued and waiting for transmission.
  pending,

  /// Currently executing network request.
  inFlight,

  /// Successfully sent and processed by server.
  completed,

  /// Failed transiently; scheduled for retry.
  failed,

  /// Max retries exceeded; moved to dead-letter storage.
  deadLetter,
}

/// Represents a persistent network request waiting to be delivered.
class OutboxRequest {
  /// Unique identifier for this request item.
  final String id;

  /// Target endpoint URL or path.
  final String endpoint;

  /// HTTP method (GET, POST, PUT, DELETE, PATCH).
  final String method;

  /// Request body payload as a JSON-encodable map or raw string.
  final dynamic payload;

  /// Optional HTTP request headers.
  final Map<String, String>? headers;

  /// Optional unique key to guarantee exactly-once execution on server.
  final String? idempotencyKey;

  /// Scheduling priority.
  final OutboxPriority priority;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Number of delivery attempts made so far.
  final int attempts;

  /// Timestamp when the next retry attempt is permitted.
  final DateTime? nextRetryAt;

  /// Current processing status.
  final OutboxItemStatus status;

  /// Most recent error message if attempt failed.
  final String? lastError;

  /// Creates an [OutboxRequest].
  OutboxRequest({
    required this.id,
    required this.endpoint,
    this.method = 'POST',
    this.payload,
    this.headers,
    this.idempotencyKey,
    this.priority = OutboxPriority.normal,
    DateTime? createdAt,
    this.attempts = 0,
    this.nextRetryAt,
    this.status = OutboxItemStatus.pending,
    this.lastError,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Converts this request to a JSON map for storage.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'endpoint': endpoint,
      'method': method,
      'payload': payload,
      'headers': headers,
      'idempotencyKey': idempotencyKey,
      'priority': priority.name,
      'createdAt': createdAt.toIso8601String(),
      'attempts': attempts,
      'nextRetryAt': nextRetryAt?.toIso8601String(),
      'status': status.name,
      'lastError': lastError,
    };
  }

  /// Deserializes an [OutboxRequest] from a JSON map.
  factory OutboxRequest.fromJson(Map<String, dynamic> json) {
    return OutboxRequest(
      id: json['id'] as String,
      endpoint: json['endpoint'] as String,
      method: json['method'] as String? ?? 'POST',
      payload: json['payload'],
      headers: (json['headers'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, v.toString()),
      ),
      idempotencyKey: json['idempotencyKey'] as String?,
      priority: OutboxPriority.values.firstWhere(
        (p) => p.name == json['priority'],
        orElse: () => OutboxPriority.normal,
      ),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      nextRetryAt: json['nextRetryAt'] != null
          ? DateTime.tryParse(json['nextRetryAt'] as String)
          : null,
      status: OutboxItemStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => OutboxItemStatus.pending,
      ),
      lastError: json['lastError'] as String?,
    );
  }

  /// Creates a copy of this request with updated fields.
  OutboxRequest copyWith({
    String? id,
    String? endpoint,
    String? method,
    dynamic payload,
    Map<String, String>? headers,
    String? idempotencyKey,
    OutboxPriority? priority,
    DateTime? createdAt,
    int? attempts,
    DateTime? nextRetryAt,
    OutboxItemStatus? status,
    String? lastError,
  }) {
    return OutboxRequest(
      id: id ?? this.id,
      endpoint: endpoint ?? this.endpoint,
      method: method ?? this.method,
      payload: payload ?? this.payload,
      headers: headers ?? this.headers,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      attempts: attempts ?? this.attempts,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      status: status ?? this.status,
      lastError: lastError ?? this.lastError,
    );
  }
}

/// Configurable exponential backoff retry strategy with jitter.
class RetryPolicy {
  /// Maximum number of delivery attempts before marking as dead letter.
  final int maxAttempts;

  /// Initial backoff delay for the first retry.
  final Duration initialDelay;

  /// Upper ceiling clamp on retry delay.
  final Duration maxDelay;

  /// Multiplier applied on each successive failure.
  final double backoffMultiplier;

  /// Whether to add randomized jitter to prevent thundering herd spikes.
  final bool enableJitter;

  /// Creates a [RetryPolicy].
  const RetryPolicy({
    this.maxAttempts = 5,
    this.initialDelay = const Duration(seconds: 2),
    this.maxDelay = const Duration(minutes: 5),
    this.backoffMultiplier = 2.0,
    this.enableJitter = true,
  });

  /// Computes the delay before attempt number [attempt] (1-indexed).
  Duration computeNextDelay(int attempt) {
    if (attempt <= 0) {
      return Duration.zero;
    }

    final double exponentialMs = initialDelay.inMilliseconds *
        math.pow(backoffMultiplier, attempt - 1).toDouble();
    double delayMs =
        math.min(exponentialMs, maxDelay.inMilliseconds.toDouble());

    if (enableJitter) {
      final double jitterFactor =
          0.8 + (math.Random().nextDouble() * 0.4); // 0.8x to 1.2x
      delayMs *= jitterFactor;
    }

    return Duration(milliseconds: delayMs.toInt());
  }
}
