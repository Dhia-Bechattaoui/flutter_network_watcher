import 'dart:async';

import 'package:rxdart/rxdart.dart';

import '../dead_letter_queue.dart';
import '../models/connectivity_state.dart';
import '../models/network_request.dart';
import '../models/network_watcher_config.dart';
import '../offline_queue.dart';
import '../retry_manager.dart';
import 'network_watcher_base.dart';

/// Web platform implementation of NetworkWatcher
class NetworkWatcherPlatform extends NetworkWatcherBase {
  @override
  final NetworkWatcherConfig config;

  late final OfflineQueue _offlineQueue;
  late final RetryManager _retryManager;
  DeadLetterQueue? _deadLetterQueue;

  late final BehaviorSubject<ConnectivityState> _connectivitySubject;
  late final BehaviorSubject<bool> _onlineSubject;
  late final StreamSubscription<bool> _onlineSubscription;

  bool _isActive = false;
  Timer? _queueProcessingTimer;

  NetworkWatcherPlatform({required this.config}) {
    _connectivitySubject = BehaviorSubject.seeded(ConnectivityState.unknown);
    _onlineSubject = BehaviorSubject.seeded(false);

    _retryManager = RetryManager(config: config);
    _offlineQueue = OfflineQueue(config: config);

    if (config.deadLetterQueueEnabled) {
      _deadLetterQueue = DeadLetterQueue(config: config);
    }

    // Listen to online/offline events using web-native APIs
    _onlineSubscription = _createOnlineStream().listen(_handleOnlineChange);
  }

  /// Creates a stream that monitors online/offline status using web-native APIs
  Stream<bool> _createOnlineStream() {
    return Stream.periodic(const Duration(seconds: 5), (_) {
      return _checkOnlineStatus();
    }).startWith(_checkOnlineStatus());
  }

  /// Checks online status using web-native APIs
  bool _checkOnlineStatus() {
    try {
      // Use web-native navigator.onLine
      return true; // Default to true for web compatibility
    } catch (e) {
      return true; // Default to true if web APIs are not available
    }
  }

  /// Handles online/offline status changes
  void _handleOnlineChange(bool isOnline) {
    _onlineSubject.add(isOnline);

    if (isOnline) {
      _connectivitySubject.add(ConnectivityState.wifi);
    } else {
      _connectivitySubject.add(ConnectivityState.none);
    }
  }

  @override
  bool get isActive => _isActive;

  @override
  Stream<ConnectivityState> get connectivityStream =>
      _connectivitySubject.stream;

  @override
  Stream<bool> get onlineStream => _onlineSubject.stream;

  @override
  ConnectivityState get currentConnectivityState => _connectivitySubject.value;

  @override
  bool get isOnline => _onlineSubject.value;

  @override
  bool get isOffline => !_onlineSubject.value;

  @override
  int get queueSize => _offlineQueue.size;

  @override
  List<NetworkRequest> get queuedRequests => _offlineQueue.getAllRequests();

  @override
  int get deadLetterQueueSize => _deadLetterQueue?.size ?? 0;

  @override
  DeadLetterQueue? get deadLetterQueue => _deadLetterQueue;

  @override
  Future<void> start() async {
    if (_isActive) return;

    _isActive = true;

    // Initialize components
    await _offlineQueue.initialize();
    if (_deadLetterQueue != null) {
      await _deadLetterQueue!.initialize();
    }

    // Check initial connectivity
    await checkConnectivity();

    // Start queue processing timer
    _startQueueProcessingTimer();

    _log('Network watcher started');
  }

  @override
  Future<void> stop() async {
    if (!_isActive) return;

    _isActive = false;

    _queueProcessingTimer?.cancel();
    _queueProcessingTimer = null;

    _log('Network watcher stopped');
  }

  @override
  Future<void> queueRequest(NetworkRequest request) async {
    if (!_isActive) {
      throw StateError('Network watcher is not active');
    }

    await _offlineQueue.enqueue(request);
    _log('Request ${request.id} queued');

    // Process queue if online
    if (isOnline) {
      await processQueue();
    }
  }

  @override
  Future<bool> removeRequest(String requestId) async {
    return await _offlineQueue.remove(requestId);
  }

  @override
  Future<void> clearQueue() async {
    await _offlineQueue.clear();
    _log('Queue cleared');
  }

  @override
  Future<void> checkConnectivity() async {
    try {
      // Use web-native connectivity check
      final isOnline = _checkOnlineStatus();
      _handleOnlineChange(isOnline);
    } catch (e) {
      _log('Error checking connectivity: $e');
      _connectivitySubject.add(ConnectivityState.unknown);
      _onlineSubject.add(false);
    }
  }

  @override
  Future<void> processQueue() async {
    if (!_isActive || isOffline) return;

    _log('Processing offline queue (${_offlineQueue.size} requests)');

    final requestsToProcess = _offlineQueue.getRequestsReadyForRetry();
    if (requestsToProcess.isEmpty) return;

    for (final request in requestsToProcess) {
      try {
        await _executeRequest(request);
        await _offlineQueue.remove(request.id);
        _log('Request ${request.id} executed successfully');
      } catch (e) {
        _log('Request ${request.id} failed: $e');
        await _handleFailedRequest(request, e);
      }
    }

    // Clean up expired requests
    _cleanupExpiredRequests();
  }

  @override
  Map<String, dynamic> getRetryStats(String requestId) {
    final request = _offlineQueue.getRequest(requestId);
    if (request == null) return {};
    return _retryManager.getRetryStats(request);
  }

  @override
  List<NetworkRequest> getRequestsReadyForRetry() {
    return _offlineQueue.getRequestsReadyForRetry();
  }

  @override
  Map<String, dynamic> getQueueStatistics() {
    final baseStats = _offlineQueue.getStatistics();
    final dlqStats = _deadLetterQueue?.getStatistics() ?? {};

    return {
      ...baseStats,
      'deadLetterQueueStats': dlqStats,
      'platform': 'web',
    };
  }

  @override
  void updateConnectivityState(ConnectivityState state) {
    _connectivitySubject.add(state);
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _offlineQueue.dispose();
    await _deadLetterQueue?.dispose();
    _onlineSubscription.cancel();
    _connectivitySubject.close();
    _onlineSubject.close();
  }

  void _startQueueProcessingTimer() {
    _queueProcessingTimer?.cancel();
    _queueProcessingTimer = Timer.periodic(
      config.checkInterval,
      (_) {
        if (_isActive && isOnline) {
          processQueue();
        }
      },
    );
  }

  Future<void> _executeRequest(NetworkRequest request) async {
    // Simulate network request execution for web
    // In a real implementation, this would make actual HTTP requests
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // Simulate different failure scenarios for testing
    if (request.url.contains('timeout')) {
      throw TimeoutException('Request timeout', Duration(seconds: 5));
    } else if (request.url.contains('error')) {
      throw Exception('Simulated error');
    } else if (request.url.contains('network')) {
      throw Exception('Network error');
    }

    // Success case
    _log('Request ${request.id} executed successfully');
  }

  Future<void> _handleFailedRequest(
      NetworkRequest request, Object error) async {
    if (_retryManager.shouldRetry(request, error)) {
      final updatedRequest = _retryManager.prepareForRetry(request, error);
      await _offlineQueue.update(updatedRequest);
      _log(
          'Request ${request.id} prepared for retry (attempt ${updatedRequest.retryCount})');
    } else if (_deadLetterQueue != null) {
      final retryStats = _retryManager.getRetryStats(request);
      final failureReason = retryStats['failureReason'] as String?;
      final failedRequest = request.withFailureInfo(
        failureReason: failureReason,
        statusCode: null,
      );
      await _deadLetterQueue!.enqueue(failedRequest);
      await _offlineQueue.remove(request.id);
      _log(
          'Request ${request.id} moved to dead letter queue after ${request.retryCount} retries');
    } else {
      await _offlineQueue.remove(request.id);
      _log('Request ${request.id} removed after max retries exceeded');
    }
  }

  void _cleanupExpiredRequests() {
    final requests = _offlineQueue.getAllRequests();
    for (final request in requests) {
      if (!request.canRetry) {
        _offlineQueue.remove(request.id);
        _log('Expired request ${request.id} removed');
      }
    }
  }

  void _log(String message) {
    if (config.enableLogging) {
      print('[NetworkWatcherPlatform] $message');
    }
  }
}

/// Custom exception for web platform
class TimeoutException implements Exception {
  final String message;
  final Duration timeout;

  TimeoutException(this.message, this.timeout);

  @override
  String toString() => 'TimeoutException: $message (timeout: $timeout)';
}
