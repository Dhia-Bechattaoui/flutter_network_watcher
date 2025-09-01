import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/network_request.dart';
import 'models/network_watcher_config.dart';
import 'exceptions/network_exceptions.dart';
import 'retry_manager.dart';
import 'dead_letter_queue.dart';

/// Manages a queue of network requests that are executed when the device
/// comes back online
class OfflineQueue {
  /// Configuration for the queue
  final NetworkWatcherConfig config;

  /// Internal queue of requests
  final List<NetworkRequest> _queue = [];

  /// SharedPreferences instance for persistence
  SharedPreferences? _prefs;

  /// Key for storing queue data in SharedPreferences
  static const String _queueKey = 'flutter_network_watcher_queue';

  /// Whether the queue has been initialized
  bool _initialized = false;

  /// Retry manager for handling retry logic
  late final RetryManager _retryManager;

  /// Dead letter queue for failed requests
  DeadLetterQueue? _deadLetterQueue;

  /// Creates a new OfflineQueue instance
  OfflineQueue({required this.config}) {
    _retryManager = RetryManager(config: config);
    if (config.deadLetterQueueEnabled) {
      _deadLetterQueue = DeadLetterQueue(config: config);
    }
  }

  /// Number of requests in the queue
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

  /// Number of requests in the dead letter queue
  int get deadLetterQueueSize {
    if (_deadLetterQueue == null) return 0;
    return _deadLetterQueue!.size;
  }

  /// Initializes the queue and loads persisted data
  Future<void> initialize() async {
    if (_initialized) return;

    _log('Initializing offline queue');

    if (config.persistQueue) {
      _prefs = await SharedPreferences.getInstance();
      await _loadPersistedQueue();
    }

    // Initialize dead letter queue if enabled
    if (_deadLetterQueue != null) {
      await _deadLetterQueue!.initialize();
    }

    // Clean up expired requests
    await _cleanupExpiredRequests();

    _initialized = true;
    _log('Offline queue initialized with ${_queue.length} requests');
  }

  /// Adds a request to the queue
  Future<void> enqueue(NetworkRequest request) async {
    _ensureInitialized();

    // Check if queue is full
    if (_queue.length >= config.maxQueueSize) {
      throw QueueFullException(config.maxQueueSize);
    }

    // Check if request already exists
    if (_queue.any((r) => r.id == request.id)) {
      throw QueueException(
          'Request with ID ${request.id} already exists in queue');
    }

    // Add request to queue (sorted by priority, then by creation time)
    _insertByPriority(request);

    // Persist if enabled
    if (config.persistQueue) {
      await _persistQueue();
    }

    _log('Request enqueued: ${request.id} (queue size: ${_queue.length})');
  }

  /// Removes a request from the queue by ID
  Future<bool> remove(String requestId) async {
    _ensureInitialized();

    final index = _queue.indexWhere((r) => r.id == requestId);
    if (index == -1) return false;

    _queue.removeAt(index);

    // Persist if enabled
    if (config.persistQueue) {
      await _persistQueue();
    }

    _log('Request removed: $requestId (queue size: ${_queue.length})');
    return true;
  }

  /// Updates an existing request in the queue
  Future<bool> update(NetworkRequest request) async {
    _ensureInitialized();

    final index = _queue.indexWhere((r) => r.id == request.id);
    if (index == -1) return false;

    _queue[index] = request;

    // Re-sort queue to maintain priority order
    _sortQueue();

    // Persist if enabled
    if (config.persistQueue) {
      await _persistQueue();
    }

    _log('Request updated: ${request.id}');
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

  /// Gets all requests in the queue
  List<NetworkRequest> getAllRequests() {
    _ensureInitialized();
    return List.unmodifiable(_queue);
  }

  /// Gets requests by priority (higher priority first)
  List<NetworkRequest> getRequestsByPriority() {
    _ensureInitialized();
    final sorted = List<NetworkRequest>.from(_queue);
    sorted.sort((a, b) => b.priority.compareTo(a.priority));
    return sorted;
  }

  /// Gets the next request to execute (highest priority, oldest first)
  NetworkRequest? getNextRequest() {
    _ensureInitialized();
    return _queue.isEmpty ? null : _queue.first;
  }

  /// Removes and returns the next request to execute
  Future<NetworkRequest?> dequeue() async {
    _ensureInitialized();

    if (_queue.isEmpty) {
      return null;
    }

    final request = _queue.removeAt(0);

    // Persist if enabled
    if (config.persistQueue) {
      await _persistQueue();
    }

    _log('Request dequeued: ${request.id} (queue size: ${_queue.length})');
    return request;
  }

  /// Clears all requests from the queue
  Future<void> clear() async {
    _ensureInitialized();

    final count = _queue.length;
    _queue.clear();

    // Persist if enabled
    if (config.persistQueue) {
      await _persistQueue();
    }

    _log('Queue cleared ($count requests removed)');
  }

  /// Removes expired requests from the queue
  Future<int> cleanupExpiredRequests() async {
    _ensureInitialized();
    return _cleanupExpiredRequests();
  }

  /// Handles a failed request with retry logic
  Future<void> handleFailedRequest(
    NetworkRequest request,
    Object error, [
    int? statusCode,
  ]) async {
    _ensureInitialized();

    _log('Handling failed request: ${request.id} (error: $error)');

    // Check if request should be retried
    if (_retryManager.shouldRetry(request, error, statusCode)) {
      // Prepare request for retry
      final retryRequest =
          _retryManager.prepareForRetry(request, error, statusCode);

      // Update the request in the queue
      await update(retryRequest);

      _log(
          'Request ${request.id} prepared for retry (attempt ${retryRequest.retryCount}/${retryRequest.maxRetries})');
    } else {
      // Request cannot be retried, move to dead letter queue if enabled
      if (_deadLetterQueue != null) {
        final retryStats = _retryManager.getRetryStats(request);
        final failureReason = retryStats['failureReason'] as String?;
        final failedRequest = request.withFailureInfo(
          failureReason: failureReason,
          statusCode: statusCode,
        );

        await _deadLetterQueue!.enqueue(failedRequest);
        await remove(request.id);

        _log(
            'Request ${request.id} moved to dead letter queue after ${request.retryCount} retries');
      } else {
        // Remove from main queue if dead letter queue is disabled
        await remove(request.id);
        _log(
            'Request ${request.id} removed from queue after ${request.retryCount} retries');
      }
    }
  }

  /// Gets retry statistics for a specific request
  Map<String, dynamic> getRetryStats(String requestId) {
    _ensureInitialized();

    final request = getRequest(requestId);
    if (request == null) {
      return {'error': 'Request not found'};
    }

    return _retryManager.getRetryStats(request);
  }

  /// Gets all requests that are ready for retry
  List<NetworkRequest> getRequestsReadyForRetry() {
    _ensureInitialized();

    final now = DateTime.now();
    return _queue.where((request) {
      if (!request.canRetry) return false;

      // Check if enough time has passed since last retry
      if (request.lastRetryTime != null) {
        final timeSinceLastRetry = now.difference(request.lastRetryTime!);
        final requiredDelay = Duration(milliseconds: request.retryDelay ?? 0);
        return timeSinceLastRetry >= requiredDelay;
      }

      return true;
    }).toList();
  }

  /// Gets queue statistics
  Map<String, dynamic> getStatistics() {
    _ensureInitialized();

    final now = DateTime.now();
    final totalRequests = _queue.length;
    final priorityGroups = <int, int>{};
    final methodGroups = <String, int>{};
    final retryGroups = <int, int>{};
    var oldestRequest = now;
    var newestRequest = DateTime(1970);

    for (final request in _queue) {
      // Priority groups
      priorityGroups[request.priority] =
          (priorityGroups[request.priority] ?? 0) + 1;

      // Method groups
      methodGroups[request.method] = (methodGroups[request.method] ?? 0) + 1;

      // Retry count groups
      retryGroups[request.retryCount] =
          (retryGroups[request.retryCount] ?? 0) + 1;

      // Age tracking
      if (request.createdAt.isBefore(oldestRequest)) {
        oldestRequest = request.createdAt;
      }
      if (request.createdAt.isAfter(newestRequest)) {
        newestRequest = request.createdAt;
      }
    }

    final stats = {
      'totalRequests': totalRequests,
      'maxQueueSize': config.maxQueueSize,
      'utilizationPercent': (totalRequests / config.maxQueueSize * 100).round(),
      'priorityGroups': priorityGroups,
      'methodGroups': methodGroups,
      'retryGroups': retryGroups,
      'oldestRequest': oldestRequest.toIso8601String(),
      'newestRequest': newestRequest.toIso8601String(),
      'deadLetterQueueSize': deadLetterQueueSize,
    };

    // Add dead letter queue statistics if enabled
    if (_deadLetterQueue != null) {
      stats['deadLetterQueueStats'] = _deadLetterQueue!.getStatistics();
    }

    return stats;
  }

  /// Gets dead letter queue if enabled
  DeadLetterQueue? get deadLetterQueue => _deadLetterQueue;

  /// Disposes of the queue and cleans up resources
  Future<void> dispose() async {
    if (config.persistQueue && _initialized) {
      await _persistQueue();
    }

    await _deadLetterQueue?.dispose();

    _queue.clear();
    _initialized = false;
    _log('Offline queue disposed');
  }

  /// Inserts a request in the correct position based on priority and creation time
  void _insertByPriority(NetworkRequest request) {
    // Find the correct position to insert the request
    int insertIndex = 0;
    for (int i = 0; i < _queue.length; i++) {
      final existing = _queue[i];

      // Higher priority comes first
      if (request.priority > existing.priority) {
        insertIndex = i;
        break;
      }

      // Same priority: older requests come first
      if (request.priority == existing.priority &&
          request.createdAt.isBefore(existing.createdAt)) {
        insertIndex = i;
        break;
      }

      insertIndex = i + 1;
    }

    _queue.insert(insertIndex, request);
  }

  /// Sorts the queue by priority and creation time
  void _sortQueue() {
    _queue.sort((a, b) {
      // Higher priority first
      final priorityComparison = b.priority.compareTo(a.priority);
      if (priorityComparison != 0) {
        return priorityComparison;
      }

      // Same priority: older requests first
      return a.createdAt.compareTo(b.createdAt);
    });
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
          _log('Failed to parse persisted request: $e');
        }
      }

      // Sort the loaded queue
      _sortQueue();

      _log('Loaded ${_queue.length} persisted requests');
    } on FormatException catch (e) {
      _log('Failed to load persisted queue: $e');
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
      _log('Failed to persist queue: $e');
      throw PersistenceException('Failed to persist queue: $e');
    }
  }

  /// Removes expired requests from the queue
  Future<int> _cleanupExpiredRequests() async {
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
      _log('Cleaned up $removedCount expired requests');
    }

    return removedCount;
  }

  /// Ensures the queue is initialized
  void _ensureInitialized() {
    if (!_initialized) {
      throw const QueueException(
          'Queue not initialized. Call initialize() first.');
    }
  }

  /// Logs a message if logging is enabled
  void _log(String message) {
    if (config.enableLogging && kDebugMode) {
      debugPrint('[OfflineQueue] $message');
    }
  }
}
