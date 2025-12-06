import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_network_watcher/flutter_network_watcher.dart';

void main() {
  runApp(const MyApp());
}

/// Main application widget that sets up the Material app.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Network Watcher - Complete Features Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const FeaturesDemo(),
    );
  }
}

/// Comprehensive demo showcasing all features of the NetworkWatcher package.
class FeaturesDemo extends StatefulWidget {
  const FeaturesDemo({super.key});

  @override
  State<FeaturesDemo> createState() => _FeaturesDemoState();
}

class _FeaturesDemoState extends State<FeaturesDemo>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late NetworkWatcher _networkWatcher;

  // Connectivity monitoring
  ConnectivityState _connectivityState = ConnectivityState.unknown;
  bool _isOnline = false;
  final List<String> _connectivityHistory = [];

  // Queue management
  List<NetworkRequest> _queuedRequests = [];
  int _queueSize = 0;
  Map<String, dynamic> _queueStats = {};

  // Dead letter queue
  List<NetworkRequest> _deadLetterRequests = [];
  int _deadLetterSize = 0;
  Map<String, dynamic> _deadLetterStats = {};

  // Analytics

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _initializeNetworkWatcher();
  }

  Future<void> _initializeNetworkWatcher() async {
    // Create network watcher with comprehensive configuration
    _networkWatcher = NetworkWatcher(
      config: NetworkWatcherConfig.reliabilityOptimized.copyWith(
        enableLogging: true,
        deadLetterQueueEnabled: true,
        maxDeadLetterQueueSize: 100,
        retryDelayStrategy: NetworkWatcherConfig.exponentialBackoffWithJitter,
      ),
    );

    await _networkWatcher.start();

    // Listen to connectivity changes
    _networkWatcher.connectivityStream.listen((state) {
      setState(() {
        _connectivityState = state;
        _connectivityHistory.insert(
          0,
          '${_formatTime(DateTime.now())}: ${state.description}',
        );
        if (_connectivityHistory.length > 20) {
          _connectivityHistory.removeLast();
        }
      });
    });

    // Listen to online/offline status
    _networkWatcher.onlineStream.listen((isOnline) {
      setState(() {
        _isOnline = isOnline;
      });
    });

    // Update information periodically
    _updateAllInfo();
    _startUpdateTimer();
  }

  void _startUpdateTimer() {
    Stream.periodic(const Duration(seconds: 2)).listen((_) {
      _updateAllInfo();
    });
  }

  void _updateAllInfo() {
    setState(() {
      _queueSize = _networkWatcher.queueSize;
      _queuedRequests = _networkWatcher.queuedRequests;
      _queueStats = _networkWatcher.getQueueStatistics();

      _deadLetterSize = _networkWatcher.deadLetterQueueSize;
      if (_networkWatcher.deadLetterQueue != null) {
        _deadLetterRequests = _networkWatcher.deadLetterQueue!.getAllRequests();
        _deadLetterStats = _networkWatcher.deadLetterQueue!.getStatistics();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _networkWatcher.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Watcher - All Features'),
        backgroundColor: _isOnline ? Colors.green : Colors.red,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.wifi), text: 'Connectivity'),
            Tab(icon: Icon(Icons.queue), text: 'Queue'),
            Tab(icon: Icon(Icons.replay), text: 'Retry Logic'),
            Tab(icon: Icon(Icons.priority_high), text: 'Priority'),
            Tab(icon: Icon(Icons.error_outline), text: 'Dead Letter'),
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
            Tab(icon: Icon(Icons.settings), text: 'Config'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildConnectivityTab(),
          _buildQueueTab(),
          _buildRetryLogicTab(),
          _buildPriorityTab(),
          _buildDeadLetterTab(),
          _buildAnalyticsTab(),
          _buildConfigTab(),
        ],
      ),
    );
  }

  // ==================== CONNECTIVITY MONITORING TAB ====================
  Widget _buildConnectivityTab() {
    return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                      children: [
                        Icon(
                          _isOnline ? Icons.wifi : Icons.wifi_off,
                    size: 64,
                          color: _isOnline ? Colors.green : Colors.red,
                        ),
                  const SizedBox(height: 16),
                        Text(
                          _connectivityState.description,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: _isOnline ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                  const SizedBox(height: 8),
                  Text(
                    _isOnline ? 'Device is ONLINE' : 'Device is OFFLINE',
                    style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              await _networkWatcher.checkConnectivity();
              _showSnackBar('Connectivity check triggered', Colors.blue);
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Force Connectivity Check'),
          ),
            const SizedBox(height: 16),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Connectivity History',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const Divider(),
                SizedBox(
                  height: 300,
                  child: _connectivityHistory.isEmpty
                      ? const Center(child: Text('No history yet'))
                      : ListView.builder(
                          itemCount: _connectivityHistory.length,
                          itemBuilder: (context, index) {
                            return ListTile(
                              dense: true,
                              title: Text(_connectivityHistory[index]),
                              leading: const Icon(Icons.history, size: 20),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== QUEUE MANAGEMENT TAB ====================
  Widget _buildQueueTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Queue Statistics',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                      Text(
                          'Total Requests: ${_queueStats['totalRequests'] ?? 0}'),
                      Text(
                          'Max Queue Size: ${_queueStats['maxQueueSize'] ?? 0}'),
                    Text(
                        'Utilization: ${_queueStats['utilizationPercent'] ?? 0}%'),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                        value: (_queueStats['utilizationPercent'] ?? 0) / 100,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                    onPressed: () => _addRequest(method: 'GET'),
                    icon: const Icon(Icons.get_app),
                    label: const Text('GET Request'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _addRequest(method: 'POST'),
                    icon: const Icon(Icons.send),
                    label: const Text('POST Request'),
                ),
                ElevatedButton.icon(
                    onPressed: () => _addRequest(method: 'PUT'),
                    icon: const Icon(Icons.edit),
                    label: const Text('PUT Request'),
                ),
                ElevatedButton.icon(
                    onPressed: () => _addRequest(method: 'DELETE'),
                    icon: const Icon(Icons.delete),
                    label: const Text('DELETE Request'),
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
            ],
          ),
        ),
            Expanded(
              child: Card(
            margin: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Text(
                            'Queued Requests',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Spacer(),
                      Chip(label: Text('$_queueSize')),
                        ],
                      ),
                    ),
                const Divider(),
                    Expanded(
                      child: _queuedRequests.isEmpty
                      ? const Center(child: Text('Queue is empty'))
                          : ListView.builder(
                              itemCount: _queuedRequests.length,
                              itemBuilder: (context, index) {
                                final request = _queuedRequests[index];
                            return _buildRequestTile(request);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==================== RETRY LOGIC TAB ====================
  Widget _buildRetryLogicTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Retry Logic Demonstration',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Test different retry scenarios:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _addFailingRequest(
              url: 'https://httpbin.org/status/500',
              maxRetries: 3,
              description: 'Server Error (500) - Will Retry',
            ),
            icon: const Icon(Icons.error),
            label: const Text('Add Request (500 Error)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _addFailingRequest(
              url: 'https://httpbin.org/status/429',
              maxRetries: 3,
              description: 'Rate Limit (429) - Will Retry',
            ),
            icon: const Icon(Icons.speed),
            label: const Text('Add Request (429 Rate Limit)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _addFailingRequest(
              url: 'https://httpbin.org/delay/10',
              maxRetries: 2,
              description: 'Timeout Request - Will Retry',
            ),
            icon: const Icon(Icons.timer_off),
            label: const Text('Add Request (Timeout)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _addFailingRequest(
              url: 'https://invalid-url-that-does-not-exist.com',
              maxRetries: 3,
              description: 'Network Error - Will Retry',
            ),
            icon: const Icon(Icons.network_check),
            label: const Text('Add Request (Network Error)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Retry Strategy Info',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Exponential backoff with jitter enabled\n'
                    '• Retries on: 408, 429, 500, 502, 503, 504\n'
                    '• Network errors are automatically retried\n'
                    '• Max retry delay: 5 minutes\n'
                    '• Failed requests move to Dead Letter Queue',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== PRIORITY TAB ====================
  Widget _buildPriorityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Priority-based Processing',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Higher priority requests are processed first. '
                    'Same priority requests are processed by creation time (oldest first).',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () => _addRequest(priority: 10, label: 'Critical'),
                icon: const Icon(Icons.priority_high, color: Colors.red),
                label: const Text('Critical (10)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _addRequest(priority: 7, label: 'High'),
                icon: const Icon(Icons.trending_up, color: Colors.orange),
                label: const Text('High (7)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _addRequest(priority: 5, label: 'Medium'),
                icon: const Icon(Icons.remove, color: Colors.blue),
                label: const Text('Medium (5)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _addRequest(priority: 3, label: 'Low'),
                icon: const Icon(Icons.trending_down, color: Colors.grey),
                label: const Text('Low (3)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _addRequest(priority: 1, label: 'Minimal'),
                icon: const Icon(Icons.minimize, color: Colors.grey),
                label: const Text('Minimal (1)'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                                    child: Text(
                    'Queue Order (Priority → Creation Time)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Divider(),
                ..._queuedRequests.map((request) => _buildRequestTile(request)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== DEAD LETTER QUEUE TAB ====================
  Widget _buildDeadLetterTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dead Letter Queue',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text('Failed Requests: $_deadLetterSize'),
                  if (_deadLetterStats.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                        'Total: ${_deadLetterStats['totalRequests'] ?? 0} requests'),
                    Text(
                        'Utilization: ${_deadLetterStats['utilizationPercent'] ?? 0}%'),
                  ],
                ],
              ),
                                      ),
                                    ),
                                  ),
        Expanded(
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(
                        'Failed Requests',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      Chip(
                        label: Text('$_deadLetterSize'),
                        backgroundColor: Colors.red[100],
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: _deadLetterRequests.isEmpty
                      ? const Center(
                          child:
                              Text('No failed requests in Dead Letter Queue'))
                      : ListView.builder(
                          itemCount: _deadLetterRequests.length,
                          itemBuilder: (context, index) {
                            final request = _deadLetterRequests[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              child: ListTile(
                                leading:
                                    const Icon(Icons.error, color: Colors.red),
                                title: Text('${request.method} ${request.url}'),
                                  subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('ID: ${request.id}'),
                                    if (request.failureReason != null)
                                      Text(
                                        'Failure: ${request.failureReason}',
                                        style:
                                            const TextStyle(color: Colors.red),
                                      ),
                                    if (request.lastFailureStatusCode != null)
                                      Text(
                                          'Status: ${request.lastFailureStatusCode}'),
                                    Text(
                                        'Failed after: ${request.retryCount} retries'),
                                    Text(
                                        'Created: ${_formatDateTime(request.createdAt)}'),
                                    ],
                                  ),
                                  trailing: IconButton(
                                  icon: const Icon(Icons.refresh),
                                    onPressed: () async {
                                    if (_networkWatcher.deadLetterQueue !=
                                        null) {
                                      await _networkWatcher.deadLetterQueue!
                                          .retryRequest(request.id);
                                      final retryRequest = NetworkRequest(
                                        id: request.id,
                                        method: request.method,
                                        url: request.url,
                                        headers: request.headers,
                                        body: request.body,
                                        createdAt: DateTime.now(),
                                        priority: request.priority,
                                        maxRetries: request.maxRetries,
                                      );
                                      await _networkWatcher
                                          .queueRequest(retryRequest);
                                      _showSnackBar(
                                          'Request retried', Colors.green);
                                    }
                                    },
                                ),
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
    );
  }

  // ==================== ANALYTICS TAB ====================
  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Queue Statistics',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow('Total Requests',
                      _queueStats['totalRequests']?.toString() ?? '0'),
                  _buildStatRow('Max Queue Size',
                      _queueStats['maxQueueSize']?.toString() ?? '0'),
                  _buildStatRow('Utilization',
                      '${_queueStats['utilizationPercent'] ?? 0}%'),
                  if (_queueStats['priorityGroups'] != null)
                    _buildStatRow('Priority Groups',
                        _queueStats['priorityGroups'].toString()),
                  if (_queueStats['methodGroups'] != null)
                    _buildStatRow('Method Distribution',
                        _queueStats['methodGroups'].toString()),
                  if (_queueStats['retryGroups'] != null)
                    _buildStatRow('Retry Distribution',
                        _queueStats['retryGroups'].toString()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dead Letter Queue Statistics',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow('Failed Requests',
                      _deadLetterStats['totalRequests']?.toString() ?? '0'),
                  if (_deadLetterStats['failureReasonGroups'] != null)
                    _buildStatRow('Failure Reasons',
                        _deadLetterStats['failureReasonGroups'].toString()),
                  if (_deadLetterStats['statusCodeGroups'] != null)
                    _buildStatRow('Status Codes',
                        _deadLetterStats['statusCodeGroups'].toString()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Request Retry Statistics',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  if (_queuedRequests.isNotEmpty) ...[
                    ..._queuedRequests.take(5).map((request) {
                      final stats = _networkWatcher.getRetryStats(request.id);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text('Request: ${request.id}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  'Retries: ${stats['retryCount']}/${stats['maxRetries']}'),
                              Text('Can Retry: ${stats['canRetry']}'),
                              if (stats['nextRetryDelay'] != null)
                                Text(
                                    'Next Delay: ${stats['nextRetryDelay']}ms'),
                              if (stats['failureReason'] != null)
                                Text('Failure: ${stats['failureReason']}',
                                    style: const TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      );
                    }),
                  ] else
                    const Text('No requests in queue'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== CONFIG TAB ====================
  Widget _buildConfigTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Configuration',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildConfigRow('Check Interval',
                      '${_networkWatcher.config.checkInterval.inSeconds}s'),
                  _buildConfigRow('Auto Retry',
                      _networkWatcher.config.autoRetry.toString()),
                  _buildConfigRow('Max Queue Size',
                      _networkWatcher.config.maxQueueSize.toString()),
                  _buildConfigRow('Persist Queue',
                      _networkWatcher.config.persistQueue.toString()),
                  _buildConfigRow('Enable Logging',
                      _networkWatcher.config.enableLogging.toString()),
                  _buildConfigRow('Max Retry Delay',
                      '${_networkWatcher.config.maxRetryDelay.inMinutes}min'),
                  _buildConfigRow('Retry Jitter',
                      _networkWatcher.config.retryJitter.toString()),
                  _buildConfigRow('Dead Letter Queue',
                      _networkWatcher.config.deadLetterQueueEnabled.toString()),
                  _buildConfigRow('Max DLQ Size',
                      _networkWatcher.config.maxDeadLetterQueueSize.toString()),
                  _buildConfigRow('Retryable Status Codes',
                      _networkWatcher.config.retryableStatusCodes.toString()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available Configurations',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• defaultConfig - Balanced default settings\n'
                    '• batteryOptimized - Minimal battery usage\n'
                    '• realTime - Maximum responsiveness\n'
                    '• reliabilityOptimized - Aggressive retries (Current)',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== HELPER METHODS ====================

  Future<void> _addRequest({
    String method = 'POST',
    int priority = 0,
    String? label,
  }) async {
    final request = NetworkRequest(
      id: '${method.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}',
      method: method,
      url: 'https://jsonplaceholder.typicode.com/posts',
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'title': label ?? 'Sample Request',
        'body': 'Request from Network Watcher Demo',
        'userId': math.Random().nextInt(10) + 1,
        'priority': priority,
      }),
      createdAt: DateTime.now(),
      priority: priority,
      maxRetries: 3,
      metadata: {'label': label, 'method': method},
    );

    try {
      await _networkWatcher.queueRequest(request);
      _showSnackBar('Request queued (Priority: $priority)', Colors.green);
    } catch (e) {
      _showSnackBar('Failed to queue: $e', Colors.red);
    }
  }

  Future<void> _addFailingRequest({
    required String url,
    required int maxRetries,
    required String description,
  }) async {
    final request = NetworkRequest(
      id: 'fail_${DateTime.now().millisecondsSinceEpoch}',
      method: 'GET',
      url: url,
      createdAt: DateTime.now(),
      priority: 5,
      maxRetries: maxRetries,
      metadata: {'description': description},
    );

    try {
      await _networkWatcher.queueRequest(request);
      _showSnackBar('Failing request queued', Colors.orange);
    } catch (e) {
      _showSnackBar('Failed to queue: $e', Colors.red);
    }
  }

  Future<void> _processQueue() async {
    await _networkWatcher.processQueue();
    _showSnackBar('Queue processing triggered', Colors.blue);
  }

  Future<void> _clearQueue() async {
    await _networkWatcher.clearQueue();
    _showSnackBar('Queue cleared', Colors.blue);
  }

  Widget _buildRequestTile(NetworkRequest request) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getPriorityColor(request.priority),
        child: Text(
          request.priority.toString(),
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
      title: Text('${request.method} ${request.url}'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ID: ${request.id}'),
          Text('Created: ${_formatDateTime(request.createdAt)}'),
          Text('Retries: ${request.retryCount}/${request.maxRetries}'),
          if (request.retryDelay != null)
            Text('Next retry delay: ${request.retryDelay}ms'),
          if (request.failureReason != null)
            Text(
              'Last error: ${request.failureReason}',
              style: const TextStyle(color: Colors.orange),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (request.canRetry)
            IconButton(
              icon: const Icon(Icons.info, size: 20),
              onPressed: () {
                final stats = _networkWatcher.getRetryStats(request.id);
                _showRequestStatsDialog(request, stats);
              },
            ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () async {
              await _networkWatcher.removeRequest(request.id);
              _showSnackBar('Request removed', Colors.orange);
            },
          ),
        ],
      ),
    );
  }

  void _showRequestStatsDialog(
      NetworkRequest request, Map<String, dynamic> stats) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Retry Stats: ${request.id}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  'Retry Count: ${stats['retryCount']}/${stats['maxRetries']}'),
              Text('Can Retry: ${stats['canRetry']}'),
              if (stats['lastRetryTime'] != null)
                Text('Last Retry: ${stats['lastRetryTime']}'),
              if (stats['nextRetryDelay'] != null)
                Text('Next Delay: ${stats['nextRetryDelay']}ms'),
              if (stats['failureReason'] != null)
                Text('Failure: ${stats['failureReason']}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildConfigRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
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

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}:'
        '${dateTime.second.toString().padLeft(2, '0')}';
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
}
