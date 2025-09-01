import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_network_watcher/flutter_network_watcher.dart';

/// Example demonstrating advanced retry functionality and offline queue management
class RetryExample extends StatefulWidget {
  const RetryExample({super.key});

  @override
  State<RetryExample> createState() => _RetryExampleState();
}

class _RetryExampleState extends State<RetryExample> {
  late NetworkWatcher _networkWatcher;
  final List<String> _logs = [];
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeNetworkWatcher();
  }

  @override
  void dispose() {
    _networkWatcher.dispose();
    super.dispose();
  }

  Future<void> _initializeNetworkWatcher() async {
    // Create a configuration optimized for reliability with aggressive retries
    final config = NetworkWatcherConfig.reliabilityOptimized.copyWith(
      enableLogging: true,
      retryDelayStrategy: NetworkWatcherConfig.exponentialBackoffWithJitter,
    );

    _networkWatcher = NetworkWatcher(config: config);

    // Listen to connectivity changes
    _networkWatcher.connectivityStream.listen((state) {
      _addLog('Connectivity changed: $state');
    });

    // Listen to online/offline status
    _networkWatcher.onlineStream.listen((isOnline) {
      _addLog('Network status: ${isOnline ? "Online" : "Offline"}');
    });

    await _networkWatcher.start();
    setState(() {
      _isInitialized = true;
    });

    _addLog('NetworkWatcher initialized with reliability-optimized config');
  }

  void _addLog(String message) {
    setState(() {
      _logs.insert(
          0, '${DateTime.now().toString().substring(11, 19)}: $message');
      if (_logs.length > 100) {
        _logs.removeRange(100, _logs.length);
      }
    });
  }

  Future<void> _queueRequest({
    required String id,
    required String url,
    String method = 'POST',
    int priority = 0,
    int maxRetries = 3,
    bool retryOnSpecificErrors = false,
    List<String> retryableErrorTypes = const [],
  }) async {
    try {
      final request = NetworkRequest(
        id: id,
        method: method,
        url: url,
        createdAt: DateTime.now(),
        priority: priority,
        maxRetries: maxRetries,
        retryOnSpecificErrors: retryOnSpecificErrors,
        retryableErrorTypes: retryableErrorTypes,
        metadata: {
          'description': 'Example request for $id',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      await _networkWatcher.queueRequest(request);
      _addLog(
          'Request queued: $id (priority: $priority, maxRetries: $maxRetries)');
    } catch (e) {
      _addLog('Failed to queue request: $e');
    }
  }

  Future<void> _queueVariousRequests() async {
    // Queue a high-priority request that should be retried aggressively
    await _queueRequest(
      id: 'high_priority_sync',
      url: 'https://api.example.com/sync',
      method: 'POST',
      priority: 10,
      maxRetries: 5,
    );

    // Queue a request that only retries on specific errors
    await _queueRequest(
      id: 'selective_retry',
      url: 'https://api.example.com/upload',
      method: 'PUT',
      priority: 5,
      maxRetries: 3,
      retryOnSpecificErrors: true,
      retryableErrorTypes: ['timeout', 'server_error'],
    );

    // Queue a low-priority request with minimal retries
    await _queueRequest(
      id: 'low_priority_analytics',
      url: 'https://analytics.example.com/event',
      method: 'POST',
      priority: 1,
      maxRetries: 1,
    );

    // Queue a request that will fail and demonstrate retry logic
    await _queueRequest(
      id: 'demonstrate_retries',
      url: 'https://api.example.com/fail',
      method: 'GET',
      priority: 7,
      maxRetries: 3,
    );
  }

  Future<void> _showQueueStatistics() async {
    final stats = _networkWatcher.getQueueStatistics();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Queue Statistics'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Total Requests: ${stats['totalRequests']}'),
              Text('Queue Utilization: ${stats['utilizationPercent']}%'),
              Text('Dead Letter Queue: ${stats['deadLetterQueueSize']}'),
              const SizedBox(height: 16),
              const Text('Priority Distribution:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ...(stats['priorityGroups'] as Map<dynamic, dynamic>)
                  .entries
                  .map((e) => Text('  Priority ${e.key}: ${e.value} requests')),
              const SizedBox(height: 16),
              const Text('Retry Distribution:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ...(stats['retryGroups'] as Map<dynamic, dynamic>)
                  .entries
                  .map((e) => Text('  ${e.value} retries: ${e.key} requests')),
              if (stats['deadLetterQueueStats'] != null) ...[
                const SizedBox(height: 16),
                const Text('Dead Letter Queue Stats:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                    '  Total: ${stats['deadLetterQueueStats']['totalRequests']}'),
                Text(
                    '  Utilization: ${stats['deadLetterQueueStats']['utilizationPercent']}%'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRetryStats(String requestId) async {
    final stats = _networkWatcher.getRetryStats(requestId);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Retry Stats for $requestId'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (stats.containsKey('error'))
              Text('Error: ${stats['error']}',
                  style: const TextStyle(color: Colors.red))
            else ...[
              Text(
                  'Retry Count: ${stats['retryCount']}/${stats['maxRetries']}'),
              Text('Can Retry: ${stats['canRetry']}'),
              if (stats['lastRetryTime'] != null)
                Text('Last Retry: ${stats['lastRetryTime']}'),
              if (stats['timeSinceLastRetry'] != null)
                Text(
                    'Time Since Last Retry: ${stats['timeSinceLastRetry']} seconds'),
              if (stats['nextRetryDelay'] != null)
                Text(
                    'Next Retry Delay: ${(stats['nextRetryDelay'] / 1000).round()} seconds'),
              if (stats['failureReason'] != null)
                Text('Failure Reason: ${stats['failureReason']}'),
              if (stats['lastFailureStatusCode'] != null)
                Text('Last Status Code: ${stats['lastFailureStatusCode']}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _processQueue() async {
    try {
      await _networkWatcher.processQueue();
      _addLog('Queue processing triggered');
    } catch (e) {
      _addLog('Failed to process queue: $e');
    }
  }

  Future<void> _clearQueue() async {
    try {
      await _networkWatcher.clearQueue();
      _addLog('Queue cleared');
    } catch (e) {
      _addLog('Failed to clear queue: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Retry Example'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Control Panel
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            _isInitialized ? _queueVariousRequests : null,
                        child: const Text('Queue Various Requests'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isInitialized ? _processQueue : null,
                        child: const Text('Process Queue'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isInitialized ? _showQueueStatistics : null,
                        child: const Text('Show Statistics'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isInitialized ? _clearQueue : null,
                        child: const Text('Clear Queue'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Status: ${_isInitialized ? "Initialized" : "Initializing..."}',
                  style: TextStyle(
                    color: _isInitialized ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                    'Queue Size: ${_isInitialized ? _networkWatcher.queueSize : "N/A"}'),
                Text(
                    'Dead Letter Queue: ${_isInitialized ? _networkWatcher.deadLetterQueueSize : "N/A"}'),
              ],
            ),
          ),

          // Logs
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Activity Log',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _logs.clear()),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: ListView.builder(
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          final log = _logs[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              log,
                              style: const TextStyle(
                                  fontFamily: 'monospace', fontSize: 12),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
