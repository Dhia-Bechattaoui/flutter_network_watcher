import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_network_watcher/flutter_network_watcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Network Watcher Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const NetworkWatcherDemo(),
    );
  }
}

class NetworkWatcherDemo extends StatefulWidget {
  const NetworkWatcherDemo({super.key});

  @override
  State<NetworkWatcherDemo> createState() => _NetworkWatcherDemoState();
}

class _NetworkWatcherDemoState extends State<NetworkWatcherDemo> {
  late NetworkWatcher _networkWatcher;
  ConnectivityState _connectivityState = ConnectivityState.unknown;
  bool _isOnline = false;
  int _queueSize = 0;
  List<NetworkRequest> _queuedRequests = [];
  Map<String, dynamic> _queueStats = {};

  @override
  void initState() {
    super.initState();
    _initializeNetworkWatcher();
  }

  Future<void> _initializeNetworkWatcher() async {
    _networkWatcher = NetworkWatcher(
      config: const NetworkWatcherConfig(
        checkInterval: Duration(seconds: 3),
        autoRetry: true,
        maxQueueSize: 50,
        persistQueue: true,
        enableLogging: true,
        maxRequestAge: Duration(minutes: 30),
      ),
    );

    // Start monitoring
    await _networkWatcher.start();

    // Listen to connectivity changes
    _networkWatcher.connectivityStream.listen((state) {
      setState(() {
        _connectivityState = state;
      });
    });

    // Listen to online/offline status
    _networkWatcher.onlineStream.listen((isOnline) {
      setState(() {
        _isOnline = isOnline;
      });
    });

    // Update queue information periodically
    _updateQueueInfo();
    _startQueueInfoTimer();
  }

  void _startQueueInfoTimer() {
    Stream<void>.periodic(const Duration(seconds: 2)).listen((_) {
      _updateQueueInfo();
    });
  }

  void _updateQueueInfo() {
    setState(() {
      _queueSize = _networkWatcher.queueSize;
      _queuedRequests = _networkWatcher.queuedRequests;
      // Note: In actual implementation, you would access queue statistics
      // through a public API or getter method
      _queueStats = {
        'totalRequests': _queueSize,
        'utilizationPercent': (_queueSize / 50 * 100).round(),
      };
    });
  }

  Future<void> _addSampleRequest({int priority = 1}) async {
    final request = NetworkRequest(
      id: 'request_${DateTime.now().millisecondsSinceEpoch}',
      method: 'POST',
      url: 'https://jsonplaceholder.typicode.com/posts',
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'title': 'Sample Request',
        'body': 'This is a sample request from Flutter Network Watcher',
        'userId': math.Random().nextInt(10) + 1,
      }),
      createdAt: DateTime.now(),
      priority: priority,
      maxRetries: 3,
    );

    try {
      await _networkWatcher.queueRequest(request);
      _showSnackBar('Request queued successfully', Colors.green);
    } catch (e) {
      _showSnackBar('Failed to queue request: $e', Colors.red);
    }
  }

  Future<void> _addFailingRequest() async {
    final request = NetworkRequest(
      id: 'failing_${DateTime.now().millisecondsSinceEpoch}',
      method: 'GET',
      url: 'https://httpbin.org/status/500', // This will always fail
      createdAt: DateTime.now(),
      priority: 1,
      maxRetries: 2,
    );

    try {
      await _networkWatcher.queueRequest(request);
      _showSnackBar('Failing request queued', Colors.orange);
    } catch (e) {
      _showSnackBar('Failed to queue request: $e', Colors.red);
    }
  }

  Future<void> _clearQueue() async {
    await _networkWatcher.clearQueue();
    _showSnackBar('Queue cleared', Colors.blue);
  }

  Future<void> _processQueue() async {
    await _networkWatcher.processQueue();
    _showSnackBar('Processing queue manually', Colors.purple);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _networkWatcher.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Watcher Demo'),
        backgroundColor: _isOnline ? Colors.green : Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connectivity Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connectivity Status',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _isOnline ? Icons.wifi : Icons.wifi_off,
                          color: _isOnline ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _connectivityState.description,
                          style: TextStyle(
                            color: _isOnline ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Queue Information Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Queue Information',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text('Queue Size: $_queueSize / 50'),
                    Text(
                        'Utilization: ${_queueStats['utilizationPercent'] ?? 0}%'),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _queueSize / 50,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _queueSize > 40 ? Colors.red : Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Action Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _addSampleRequest(priority: 1),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Request'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _addSampleRequest(priority: 5),
                  icon: const Icon(Icons.priority_high),
                  label: const Text('Add High Priority'),
                ),
                ElevatedButton.icon(
                  onPressed: _addFailingRequest,
                  icon: const Icon(Icons.error),
                  label: const Text('Add Failing Request'),
                ),
                ElevatedButton.icon(
                  onPressed: _processQueue,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Process Queue'),
                ),
                ElevatedButton.icon(
                  onPressed: _clearQueue,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear Queue'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Queued Requests List
            Expanded(
              child: Card(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Text(
                            'Queued Requests',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Spacer(),
                          Chip(
                            label: Text('$_queueSize'),
                            backgroundColor: Colors.blue[100],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _queuedRequests.isEmpty
                          ? const Center(
                              child: Text(
                                'No requests in queue',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _queuedRequests.length,
                              itemBuilder: (context, index) {
                                final request = _queuedRequests[index];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        _getPriorityColor(request.priority),
                                    child: Text(
                                      request.priority.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    '${request.method} ${request.url}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('ID: ${request.id}'),
                                      Text(
                                        'Created: ${_formatDateTime(request.createdAt)}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      Text(
                                        'Retries: ${request.retryCount}/${request.maxRetries}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () async {
                                      await _networkWatcher
                                          .removeRequest(request.id);
                                      _showSnackBar(
                                          'Request removed', Colors.orange);
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(int priority) {
    if (priority >= 8) return Colors.red;
    if (priority >= 5) return Colors.orange;
    if (priority >= 3) return Colors.blue;
    return Colors.grey;
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}:'
        '${dateTime.second.toString().padLeft(2, '0')}';
  }
}
