// ignore_for_file: deprecated_member_use
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:offline_outbox/offline_outbox.dart';

void main() {
  runApp(const OutboxDemoApp());
}

class OutboxDemoApp extends StatelessWidget {
  const OutboxDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offline Outbox Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          surface: Color(0xFF1E293B),
        ),
      ),
      home: const OutboxDemoScreen(),
    );
  }
}

class OutboxDemoScreen extends StatefulWidget {
  const OutboxDemoScreen({super.key});

  @override
  State<OutboxDemoScreen> createState() => _OutboxDemoScreenState();
}

class _OutboxDemoScreenState extends State<OutboxDemoScreen> {
  late final InMemoryOutboxStorage _storage;
  late final OfflineOutboxEngine _engine;

  bool _isOnline = false;
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _storage = InMemoryOutboxStorage();
    _engine = OfflineOutboxEngine(
      storage: _storage,
      retryPolicy: const RetryPolicy(
        maxAttempts: 4,
        initialDelay: Duration(seconds: 2),
      ),
      executor: (request) async {
        // Simulate network request
        await Future<void>.delayed(const Duration(milliseconds: 300));
        if (!_isOnline) {
          throw Exception('Device is offline');
        }
        return true;
      },
    );

    _engine.init().then((_) {
      _engine.onCompletedStream.listen((req) {
        if (mounted) {
          setState(() {
            _logs.insert(0,
                '✅ Delivered ${req.priority.name.toUpperCase()} -> ${req.endpoint}');
          });
        }
      });
      _engine.onFailedStream.listen((req) {
        if (mounted) {
          setState(() {
            _logs.insert(0,
                '⚠️ Retry queued (Attempt ${req.attempts}) -> ${req.endpoint}');
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }

  void _enqueueRequest(String endpoint, OutboxPriority priority,
      Map<String, dynamic> payload) async {
    final req = OutboxRequest(
      id: 'req_${Random().nextInt(99999)}',
      endpoint: endpoint,
      priority: priority,
      payload: payload,
      idempotencyKey: 'idem_${Random().nextInt(999999)}',
    );

    await _engine.enqueue(req);
    setState(() {
      _logs.insert(
          0, '📥 Enqueued ${priority.name.toUpperCase()} request to $endpoint');
    });

    if (_isOnline) {
      _engine.processQueue();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Outbox Engine',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        elevation: 0,
        backgroundColor: const Color(0xFF0F172A),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Network Simulation Header Card
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20.0),
                border: Border.all(
                  color: _isOnline
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isOnline ? Icons.wifi : Icons.wifi_off_rounded,
                    color: _isOnline
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    size: 36,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isOnline
                              ? 'Network Online'
                              : 'Device Offline (Queuing Mode)',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        Text(
                          _isOnline
                              ? 'Requests transmit directly'
                              : 'Requests persist to disk & auto-retry',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isOnline,
                    activeColor: const Color(0xFF10B981),
                    onChanged: (val) {
                      setState(() => _isOnline = val);
                      if (val) {
                        _engine.processQueue();
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Enqueue Action Buttons
            const Text('Trigger Outbox Actions',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.shopping_cart_checkout, size: 18),
                    label: const Text('Order [Critical]',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _enqueueRequest('/api/v1/orders',
                        OutboxPriority.critical, {'order_id': 101}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF38BDF8),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.person, size: 18),
                    label: const Text('Profile [High]',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _enqueueRequest('/api/v1/profile',
                        OutboxPriority.high, {'name': 'Govind'}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Queue Status Counter Stream
            StreamBuilder<int>(
              stream: _engine.pendingCountStream,
              initialData: 0,
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.layers, color: Color(0xFF38BDF8)),
                          const SizedBox(width: 10),
                          Text('Pending Queue: $count items',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF334155),
                          foregroundColor: Colors.white,
                        ),
                        onPressed:
                            count > 0 ? () => _engine.processQueue() : null,
                        child: const Text('Sync Now'),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Event Logs
            const Text('Outbox Event Log',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              height: 220,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: _logs.isEmpty
                  ? const Center(
                      child: Text('No events yet. Tap an action above.',
                          style: TextStyle(color: Color(0xFF64748B))),
                    )
                  : ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Text(
                            _logs[index],
                            style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                                color: Color(0xFFE2E8F0)),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
