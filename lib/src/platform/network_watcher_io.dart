import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';

import '../dead_letter_queue.dart';
import '../exceptions/network_exceptions.dart';
import '../models/connectivity_state.dart';
import '../models/network_request.dart';
import '../models/network_watcher_config.dart';
import '../offline_queue.dart';
import 'network_watcher_base.dart';

/// IO implementation for mobile and desktop platforms
class NetworkWatcherPlatform extends NetworkWatcherBase {
  /// Creates a new NetworkWatcher instance
  NetworkWatcherPlatform({
    this.config = NetworkWatcherConfig.defaultConfig,
  }) {
    _offlineQueue = OfflineQueue(config: config);
    _initializeConnectivityMonitoring();
  }

  /// Configuration for the network watcher
  @override
  final NetworkWatcherConfig config;

  /// Offline queue manager
  late final OfflineQueue _offlineQueue;

  /// Connectivity plugin instance
  final Connectivity _connectivity = Connectivity();

  /// Stream controller for connectivity state changes
  final BehaviorSubject<ConnectivityState> _connectivityController =
      BehaviorSubject<ConnectivityState>.seeded(ConnectivityState.unknown);

  /// Stream controller for network status (online/offline)
  final BehaviorSubject<bool> _onlineController =
      BehaviorSubject<bool>.seeded(false);

  /// Timer for periodic connectivity checks
  Timer? _connectivityTimer;

  /// Subscription to connectivity changes
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Whether the watcher is currently active
  bool _isActive = false;

  /// Whether the queue is currently being processed
  bool _isProcessingQueue = false;

  /// Expose active state
  @override
  bool get isActive => _isActive;

  /// Stream of connectivity state changes
  @override
  Stream<ConnectivityState> get connectivityStream =>
      _connectivityController.stream.distinct();

  /// Stream of online/offline status changes
  @override
  Stream<bool> get onlineStream => _onlineController.stream.distinct();

  /// Current connectivity state
  @override
  ConnectivityState get currentConnectivityState =>
      _connectivityController.value;

  /// Whether the device is currently online
  @override
  bool get isOnline => _onlineController.value;

  /// Whether the device is currently offline
  @override
  bool get isOffline => !isOnline;

  /// Number of requests currently in the offline queue
  @override
  int get queueSize => _offlineQueue.size;

  /// List of all requests in the offline queue
  @override
  List<NetworkRequest> get queuedRequests => _offlineQueue.getAllRequests();

  /// Number of requests in the dead letter queue
  @override
  int get deadLetterQueueSize => _offlineQueue.deadLetterQueueSize;

  /// Starts monitoring network connectivity
  @override
  Future<void> start() async {
    if (_isActive) {
      return;
    }

    _log('Starting NetworkWatcher');
    _isActive = true;

    // Initialize offline queue
    await _offlineQueue.initialize();

    // Check initial connectivity
    await _checkConnectivity();

    // Start listening to connectivity changes
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);

    // Start periodic connectivity checks
    _startPeriodicConnectivityCheck();

    _log('NetworkWatcher started successfully');
  }

  /// Stops monitoring network connectivity
  @override
  Future<void> stop() async {
    if (!_isActive) {
      return;
    }

    _log('Stopping NetworkWatcher');
    _isActive = false;

    // Cancel timers and subscriptions
    _connectivityTimer?.cancel();
    _connectivityTimer = null;

    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;

    // Clean up offline queue
    await _offlineQueue.dispose();

    _log('NetworkWatcher stopped');
  }

  /// Queues a network request for execution when online
  @override
  Future<void> queueRequest(NetworkRequest request) async {
    if (!_isActive) {
      throw const QueueException('NetworkWatcher is not active');
    }

    if (isOnline && config.autoRetry) {
      // If online, try to execute immediately
      try {
        await _executeRequest(request);
        return;
      } on RequestExecutionException catch (e) {
        _log('Failed to execute request immediately, queueing: $e');
        // Fall through to queue the request
      } on Exception catch (e) {
        _log('Unexpected error executing request immediately, queueing: $e');
        // Fall through to queue the request
      }
    }

    // Queue the request for later execution
    await _offlineQueue.enqueue(request);
    _log('Request queued: ${request.id}');
  }

  /// Removes a specific request from the queue
  @override
  Future<bool> removeRequest(String requestId) async {
    final removed = await _offlineQueue.remove(requestId);
    if (removed) {
      _log('Request removed from queue: $requestId');
    }
    return removed;
  }

  /// Clears all requests from the queue
  @override
  Future<void> clearQueue() async {
    await _offlineQueue.clear();
    _log('Queue cleared');
  }

  /// Forces a connectivity check
  @override
  Future<void> checkConnectivity() async {
    await _checkConnectivity();
  }

  /// Manually processes the offline queue
  @override
  Future<void> processQueue() async {
    if (!isOnline) {
      _log('Cannot process queue while offline');
      return;
    }

    await _processOfflineQueue();
  }

  /// Gets retry statistics for a specific request
  @override
  Map<String, dynamic> getRetryStats(String requestId) {
    return _offlineQueue.getRetryStats(requestId);
  }

  /// Gets all requests that are ready for retry
  @override
  List<NetworkRequest> getRequestsReadyForRetry() {
    return _offlineQueue.getRequestsReadyForRetry();
  }

  /// Gets comprehensive queue statistics
  @override
  Map<String, dynamic> getQueueStatistics() {
    return _offlineQueue.getStatistics();
  }

  /// Gets dead letter queue if enabled
  @override
  DeadLetterQueue? get deadLetterQueue => _offlineQueue.deadLetterQueue;

  /// Disposes of all resources
  @override
  Future<void> dispose() async {
    await stop();
    await _connectivityController.close();
    await _onlineController.close();
  }

  /// Initializes connectivity monitoring
  void _initializeConnectivityMonitoring() {
    // Listen for online status changes and process queue when coming back online
    onlineStream.listen((isOnline) {
      if (isOnline && config.autoRetry) {
        _processOfflineQueue();
      }
    });
  }

  /// Starts periodic connectivity checking
  void _startPeriodicConnectivityCheck() {
    _connectivityTimer = Timer.periodic(config.checkInterval, (_) {
      if (_isActive) {
        _checkConnectivity();
      }
    });
  }

  /// Handles connectivity changes from the connectivity plugin
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
    _log('Connectivity changed: $result');

    final previousState = _connectivityController.value;
    final newState = _mapConnectivityResult(result);

    _updateConnectivityState(newState);

    // If we just came back online, process the offline queue
    if (!previousState.isConnected && newState.isConnected) {
      _log('Device came back online, processing offline queue');
      _processOfflineQueue();
    }
  }

  /// Checks current connectivity and updates state
  Future<void> _checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final result =
          results.isNotEmpty ? results.first : ConnectivityResult.none;
      final state = _mapConnectivityResult(result);
      _updateConnectivityState(state);

      // Additional internet connectivity check for more accuracy
      if (state != ConnectivityState.none) {
        final hasInternet = await _checkInternetConnectivity();
        if (!hasInternet) {
          _updateConnectivityState(ConnectivityState.none);
        }
      }
    } on Exception catch (e) {
      _log('Error checking connectivity: $e');
      _updateConnectivityState(ConnectivityState.unknown);
    }
  }

  /// Performs an actual internet connectivity test
  Future<bool> _checkInternetConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (e) {
      _log('Internet connectivity test failed: $e');
      return false;
    } on TimeoutException catch (e) {
      _log('Internet connectivity test timed out: $e');
      return false;
    } on Exception catch (e) {
      _log('Unexpected error in internet connectivity test: $e');
      return false;
    }
  }

  /// Updates the connectivity state and notifies listeners
  void _updateConnectivityState(ConnectivityState state) {
    if (_connectivityController.value != state) {
      _connectivityController.add(state);
      _onlineController.add(state.isConnected);
      _log('Connectivity state updated: $state');
    }
  }

  /// Expose connectivity state update
  @override
  void updateConnectivityState(ConnectivityState state) {
    final previousState = _connectivityController.value;
    _log('updateConnectivityState called: $previousState -> $state');

    _updateConnectivityState(state);

    // If we just came back online, process the offline queue
    if (!previousState.isConnected && state.isConnected) {
      _log(
          'Device came back online via updateConnectivityState, processing offline queue');
      _processOfflineQueue();
    } else {
      _log(
          'No queue processing needed: previousState.isConnected=${previousState.isConnected}, state.isConnected=${state.isConnected}');
    }
  }

  /// Maps ConnectivityResult to ConnectivityState
  ConnectivityState _mapConnectivityResult(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return ConnectivityState.wifi;
      case ConnectivityResult.mobile:
        return ConnectivityState.mobile;
      case ConnectivityResult.ethernet:
        return ConnectivityState.ethernet;
      case ConnectivityResult.none:
        return ConnectivityState.none;
      case ConnectivityResult.bluetooth:
      case ConnectivityResult.vpn:
      case ConnectivityResult.other:
        return ConnectivityState.unknown;
    }
  }

  /// Expose connectivity result mapping
  ConnectivityState mapConnectivityResult(ConnectivityResult result) =>
      _mapConnectivityResult(result);

  /// Processes all requests in the offline queue
  Future<void> _processOfflineQueue() async {
    if (!isOnline) {
      _log('Cannot process queue while offline');
      return;
    }

    if (_isProcessingQueue) {
      _log('Queue processing already in progress, skipping');
      return;
    }

    _isProcessingQueue = true;
    _log('Processing offline queue (${_offlineQueue.size} requests)');

    try {
      // Clean up requests that can't be retried anymore
      await _cleanupExpiredRequests();

      // Get requests that are ready for retry
      final readyRequests = _offlineQueue.getRequestsReadyForRetry();
      if (readyRequests.isEmpty) {
        _log('No requests ready for retry');
        // Still clean up expired requests even if none are ready for retry
        await _cleanupExpiredRequests();
        return;
      }

      _log('Processing ${readyRequests.length} requests ready for retry');

      for (final request in readyRequests) {
        if (!isOnline) {
          _log('Went offline during processing, stopping');
          break; // Stop if we go offline during processing
        }

        _log(
            'Processing request: ${request.id} (retries: ${request.retryCount}/${request.maxRetries})');

        try {
          await _executeRequest(request);
          await _offlineQueue.remove(request.id);
          _log('Successfully executed queued request: ${request.id}');
        } on RequestExecutionException catch (e) {
          _log('Failed to execute queued request ${request.id}: $e');

          // Use the enhanced retry logic
          await _offlineQueue.handleFailedRequest(request, e);
        } on Exception catch (e) {
          _log('Unexpected error executing queued request ${request.id}: $e');

          // Use the enhanced retry logic
          await _offlineQueue.handleFailedRequest(request, e);
        }
      }
    } finally {
      _isProcessingQueue = false;
      _log('Finished processing offline queue');
    }
  }

  /// Executes a network request (placeholder implementation)
  Future<void> _executeRequest(NetworkRequest request) async {
    // This is a placeholder implementation
    // In a real implementation, you would use an HTTP client to execute the request
    _log('Executing request: ${request.method} ${request.url}');

    // Simulate network delay
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // Simulate different types of failures for testing
    if (request.url.contains('fail')) {
      throw RequestExecutionException(
        request.id,
        'Simulated request failure',
      );
    }

    if (request.url.contains('timeout')) {
      throw RequestExecutionException(
        request.id,
        'Simulated timeout',
      );
    }

    if (request.url.contains('server_error')) {
      throw RequestExecutionException(
        request.id,
        'Simulated server error',
        500,
      );
    }

    if (request.url.contains('rate_limit')) {
      throw RequestExecutionException(
        request.id,
        'Simulated rate limit',
        429,
      );
    }
  }

  /// Cleans up requests that can't be retried anymore
  Future<void> _cleanupExpiredRequests() async {
    final requestsToRemove = <String>[];

    for (final request in _offlineQueue.getAllRequests()) {
      if (!request.canRetry) {
        requestsToRemove.add(request.id);
        _log('Request ${request.id} exceeded max retries, marking for removal');
      }
    }

    for (final requestId in requestsToRemove) {
      await _offlineQueue.remove(requestId);
      _log('Removed expired request: $requestId');
    }
  }

  /// Logs a message if logging is enabled
  void _log(String message) {
    if (config.enableLogging && kDebugMode) {
      debugPrint('[NetworkWatcher] $message');
    }
  }
}
