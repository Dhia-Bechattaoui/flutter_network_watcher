import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/network_request.dart';
import 'models/network_watcher_config.dart';
import 'exceptions/network_exceptions.dart';

/// Manages a queue of failed requests that have exceeded retry limits
class DeadLetterQueue {
  /// Configuration for the dead letter queue
  final NetworkWatcherConfig config;

  /// Internal queue of failed requests
  final List<NetworkRequest> _queue = [];

  /// SharedPreferences instance for persistence
  SharedPreferences? _prefs;

  /// Key for storing dead letter queue data in SharedPreferences
  static const String _queueKey = 'flutter_network_watcher_dead_letter_queue';

  /// Whether the queue has been initialized
  bool _initialized = false;

  /// Creates a new DeadLetterQueue instance
  DeadLetterQueue({required this.config});

  /// Number of requests in the dead letter queue
  int get size {
    _ensureInitialized();
    return _queue.length;
  }

  /// Whether the queue is empty
  bool get isEmpty {
    _ensureInitialized();
    return _queue.isEmpty;
  }

  /// Whether the queue is not empty
  bool get isNotEmpty {
    _ensureInitialized();
    return _queue.isNotEmpty;
  }

  /// Initializes the queue and loads persisted data
  Future<void> initialize() async {
    if (_initialized) return;

    _log('Initializing dead letter queue');

    if (config.persistQueue) {
      _prefs = await SharedPreferences.getInstance();
      await _loadPersistedQueue();
    }

    // Clean up old requests
    await _cleanupOldRequests();

    _initialized = true;
    _log('Dead letter queue initialized with ${_queue.length} requests');
  }

  /// Adds a failed request to the dead letter queue
  Future<void> enqueue(NetworkRequest request) async {
    _ensureInitialized();

    // Check if queue is full
    if (_queue.length >= config.maxDeadLetterQueueSize) {
      // Remove oldest request to make room
      _queue.removeAt(0);
      _log('Removed oldest request to make room in dead letter queue');
    }

    // Check if request already exists
    if (_queue.any((r) => r.id == request.id)) {
      _log(
          'Request with ID ${request.id} already exists in dead letter queue, updating');
      await remove(request.id);
    }

    // Add request to queue (sorted by creation time, oldest first)
    _insertByCreationTime(request);

    // Persist if enabled
    if (config.persistQueue) {
      await _persistQueue();
    }

    _log(
        'Request added to dead letter queue: ${request.id} (queue size: ${_queue.length})');
  }

  /// Removes a request from the dead letter queue by ID
  Future<bool> remove(String requestId) async {
    _ensureInitialized();

    final index = _queue.indexWhere((r) => r.id == requestId);
    if (index == -1) return false;

    _queue.removeAt(index);

    // Persist if enabled
    if (config.persistQueue) {
      await _persistQueue();
    }

    _log(
        'Request removed from dead letter queue: $requestId (queue size: ${_queue.length})');
    return true;
  }

  /// Gets a request by ID
  NetworkRequest? getRequest(String requestId) {
    _ensureInitialized();
    try {
      return _queue.firstWhere((r) => r.id == requestId);
    } on StateError {
      return null;
    }
  }

  /// Gets all requests in the dead letter queue
  List<NetworkRequest> getAllRequests() {
    _ensureInitialized();
    return List.unmodifiable(_queue);
  }

  /// Gets requests by failure reason
  List<NetworkRequest> getRequestsByFailureReason(String failureReason) {
    _ensureInitialized();
    return _queue.where((r) => r.failureReason == failureReason).toList();
  }

  /// Gets requests by HTTP status code
  List<NetworkRequest> getRequestsByStatusCode(int statusCode) {
    _ensureInitialized();
    return _queue.where((r) => r.lastFailureStatusCode == statusCode).toList();
  }

  /// Gets requests by age (older than specified duration)
  List<NetworkRequest> getRequestsOlderThan(Duration age) {
    _ensureInitialized();
    final cutoff = DateTime.now().subtract(age);
    return _queue.where((r) => r.createdAt.isBefore(cutoff)).toList();
  }

  /// Attempts to retry a request from the dead letter queue
  Future<bool> retryRequest(String requestId) async {
    _ensureInitialized();

    final request = getRequest(requestId);
    if (request == null) return false;

    // Remove from dead letter queue
    await remove(requestId);

    _log('Request ${requestId} removed from dead letter queue for retry');
    return true;
  }

  /// Clears all requests from the dead letter queue
  Future<void> clear() async {
    _ensureInitialized();

    final count = _queue.length;
    _queue.clear();

    // Persist if enabled
    if (config.persistQueue) {
      await _persistQueue();
    }

    _log('Dead letter queue cleared ($count requests removed)');
  }

  /// Removes old requests from the queue
  Future<int> cleanupOldRequests() async {
    _ensureInitialized();
    return _cleanupOldRequests();
  }

  /// Gets dead letter queue statistics
  Map<String, dynamic> getStatistics() {
    _ensureInitialized();

    final now = DateTime.now();
    final totalRequests = _queue.length;
    final failureReasonGroups = <String, int>{};
    final statusCodeGroups = <int, int>{};
    final methodGroups = <String, int>{};
    var oldestRequest = now;
    var newestRequest = DateTime(1970);

    for (final request in _queue) {
      // Failure reason groups
      final reason = request.failureReason ?? 'unknown';
      failureReasonGroups[reason] = (failureReasonGroups[reason] ?? 0) + 1;

      // Status code groups
      if (request.lastFailureStatusCode != null) {
        statusCodeGroups[request.lastFailureStatusCode!] =
            (statusCodeGroups[request.lastFailureStatusCode!] ?? 0) + 1;
      }

      // Method groups
      methodGroups[request.method] = (methodGroups[request.method] ?? 0) + 1;

      // Age tracking
      if (request.createdAt.isBefore(oldestRequest)) {
        oldestRequest = request.createdAt;
      }
      if (request.createdAt.isAfter(newestRequest)) {
        newestRequest = request.createdAt;
      }
    }

    return {
      'totalRequests': totalRequests,
      'maxQueueSize': config.maxDeadLetterQueueSize,
      'utilizationPercent':
          (totalRequests / config.maxDeadLetterQueueSize * 100).round(),
      'failureReasonGroups': failureReasonGroups,
      'statusCodeGroups': statusCodeGroups,
      'methodGroups': methodGroups,
      'oldestRequest': oldestRequest.toIso8601String(),
      'newestRequest': newestRequest.toIso8601String(),
      'averageAgeHours': totalRequests > 0
          ? _queue.fold(
                  0.0, (sum, r) => sum + now.difference(r.createdAt).inHours) /
              totalRequests
          : 0.0,
    };
  }

  /// Exports dead letter queue data for analysis
  Map<String, dynamic> exportData() {
    _ensureInitialized();

    return {
      'exportedAt': DateTime.now().toIso8601String(),
      'queueSize': _queue.length,
      'requests': _queue.map((r) => r.toJson()).toList(),
      'statistics': getStatistics(),
    };
  }

  /// Disposes of the queue and cleans up resources
  Future<void> dispose() async {
    if (config.persistQueue && _initialized) {
      await _persistQueue();
    }
    _queue.clear();
    _initialized = false;
    _log('Dead letter queue disposed');
  }

  /// Inserts a request in the correct position based on creation time
  void _insertByCreationTime(NetworkRequest request) {
    // Find the correct position to insert the request (oldest first)
    int insertIndex = 0;
    for (int i = 0; i < _queue.length; i++) {
      final existing = _queue[i];
      if (request.createdAt.isBefore(existing.createdAt)) {
        insertIndex = i;
        break;
      }
      insertIndex = i + 1;
    }

    _queue.insert(insertIndex, request);
  }

  /// Loads the persisted queue from SharedPreferences
  Future<void> _loadPersistedQueue() async {
    try {
      final queueData = _prefs?.getString(_queueKey);
      if (queueData == null) {
        return;
      }

      final List<dynamic> jsonList = jsonDecode(queueData) as List<dynamic>;
      for (final jsonItem in jsonList) {
        try {
          final request =
              NetworkRequest.fromJson(jsonItem as Map<String, dynamic>);
          _queue.add(request);
        } on FormatException catch (e) {
          _log('Failed to parse persisted dead letter request: $e');
        }
      }

      // Sort the loaded queue by creation time
      _queue.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      _log('Loaded ${_queue.length} persisted dead letter requests');
    } on FormatException catch (e) {
      _log('Failed to load persisted dead letter queue: $e');
      // Clear corrupted data
      await _prefs?.remove(_queueKey);
    }
  }

  /// Persists the current queue to SharedPreferences
  Future<void> _persistQueue() async {
    if (_prefs == null) {
      return;
    }

    try {
      final jsonList = _queue.map((r) => r.toJson()).toList();
      final queueData = jsonEncode(jsonList);
      await _prefs!.setString(_queueKey, queueData);
    } on FormatException catch (e) {
      _log('Failed to persist dead letter queue: $e');
      throw PersistenceException('Failed to persist dead letter queue: $e');
    }
  }

  /// Removes old requests from the queue
  Future<int> _cleanupOldRequests() async {
    final now = DateTime.now();
    final originalSize = _queue.length;

    _queue.removeWhere((request) {
      final age = now.difference(request.createdAt);
      return age > config.maxRequestAge;
    });

    final removedCount = originalSize - _queue.length;

    if (removedCount > 0) {
      // Persist if enabled
      if (config.persistQueue) {
        await _persistQueue();
      }
      _log('Cleaned up $removedCount old requests from dead letter queue');
    }

    return removedCount;
  }

  /// Ensures the queue is initialized
  void _ensureInitialized() {
    if (!_initialized) {
      throw const QueueException(
          'Dead letter queue not initialized. Call initialize() first.');
    }
  }

  /// Logs a message if logging is enabled
  void _log(String message) {
    if (config.enableLogging && kDebugMode) {
      debugPrint('[DeadLetterQueue] $message');
    }
  }
}
