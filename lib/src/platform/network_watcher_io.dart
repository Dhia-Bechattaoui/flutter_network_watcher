import 'dart:async';

import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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
  NetworkWatcherPlatform({this.config = NetworkWatcherConfig.defaultConfig}) {
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
  final BehaviorSubject<bool> _onlineController = BehaviorSubject<bool>.seeded(
    false,
  );

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
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
    );

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
  Future<void> queueRequest(final NetworkRequest request) async {
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
  Future<bool> removeRequest(final String requestId) async {
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
  Map<String, dynamic> getRetryStats(final String requestId) =>
      _offlineQueue.getRetryStats(requestId);

  /// Gets all requests that are ready for retry
  @override
  List<NetworkRequest> getRequestsReadyForRetry() =>
      _offlineQueue.getRequestsReadyForRetry();

  /// Gets comprehensive queue statistics
  @override
  Map<String, dynamic> getQueueStatistics() => _offlineQueue.getStatistics();

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
    // Listen for online status changes and process queue when coming back
    // online
    onlineStream.listen((final isOnline) {
      if (isOnline && config.autoRetry) {
        unawaited(_processOfflineQueue());
      }
    });
  }

  /// Starts periodic connectivity checking
  /// Uses shorter intervals when offline for faster reconnection detection
  void _startPeriodicConnectivityCheck() {
    _connectivityTimer?.cancel();
    _connectivityTimer = Timer.periodic(config.checkInterval, (_) {
      if (_isActive) {
        unawaited(_checkConnectivity());
      }
    });
  }

  /// Handles connectivity changes from the connectivity plugin
  Future<void> _onConnectivityChanged(
    final List<ConnectivityResult> results,
  ) async {
    final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
    _log('=== Connectivity stream event: $result ===');

    final previousState = _connectivityController.value;

    // Always check connectivity when the stream fires - this includes
    // internet verification
    await _checkConnectivity();

    // If we just came back online, process the offline queue
    final currentState = _connectivityController.value;
    if (!previousState.isConnected && currentState.isConnected) {
      _log('Device came back online, processing offline queue');
      unawaited(_processOfflineQueue());
    }
  }

  /// Checks current connectivity and updates state
  /// PRIORITY: Internet connectivity check FIRST, then connectivity_plus
  /// This ensures we never show "connected" when there's no actual internet
  Future<void> _checkConnectivity() async {
    try {
      final previousState = _connectivityController.value;

      _log('[NetworkWatcher] Starting connectivity check...');

      // STEP 1: ALWAYS check internet connectivity FIRST
      // This is the source of truth - if no internet, we're offline
      // regardless of connectivity_plus
      final hasInternet = await _checkInternetConnectivity();

      // STEP 2: Check connectivity_plus to determine connection type (if
      // internet is available)
      final results = await _connectivity.checkConnectivity();
      final connectivityResult = results.isNotEmpty
          ? results.first
          : ConnectivityResult.none;

      _log(
        '[NetworkWatcher] Internet check: $hasInternet, '
        'Connectivity_plus: $connectivityResult',
      );

      // STEP 3: Update state based on internet connectivity (not
      // connectivity_plus)
      if (!hasInternet) {
        // NO INTERNET = OFFLINE (regardless of what connectivity_plus says)
        _log('[NetworkWatcher] NO INTERNET - Setting state to OFFLINE');
        if (previousState.isConnected) {
          _log('[NetworkWatcher] Device just went offline');
        }
        _updateConnectivityState(ConnectivityState.none);
        return;
      }

      // We have internet - now determine the connection type from
      // connectivity_plus
      ConnectivityState newState;
      if (connectivityResult == ConnectivityResult.none) {
        // connectivity_plus says no connection, but we have internet
        // Default to WiFi in this case
        newState = ConnectivityState.wifi;
      } else {
        // Map the connectivity result to our state
        newState = _mapConnectivityResult(connectivityResult);
      }

      _log('[NetworkWatcher] Internet available - Setting state to: $newState');
      _updateConnectivityState(newState);

      // If we just came back online, process the offline queue
      if (!previousState.isConnected && newState.isConnected) {
        _log(
          '[NetworkWatcher] Device came back online, processing offline queue',
        );
        unawaited(_processOfflineQueue());
      }
    } on Exception catch (e) {
      // Catch all exceptions (including SocketException, OSError, etc.)
      // This ensures no exceptions escape and crash the app
      _log(
        '[NetworkWatcher] ERROR checking connectivity: $e (${e.runtimeType})',
      );
      // On error, assume offline to be safe
      _updateConnectivityState(ConnectivityState.none);
    }
  }

  /// Performs an actual internet connectivity test
  /// Uses a shorter timeout for faster detection of disconnections
  /// Returns false silently if there's no internet (expected behavior)
  /// All exceptions are caught and handled silently - no debugger breaks
  Future<bool> _checkInternetConnectivity() async =>
      // Use a safer lookup that handles all exceptions internally
      // This prevents debugger from breaking on expected exceptions
      _safeInternetLookup('google.com');

  /// Safely performs internet connectivity check using HTTP request
  /// This method prevents debugger breaks by using HTTP instead of DNS lookup
  /// Returns true if internet is available, false otherwise (no exceptions
  /// thrown)
  Future<bool> _safeInternetLookup(final String hostname) async {
    // Use HTTP request instead of DNS lookup to avoid SocketException
    // HTTP requests are caught more gracefully and don't trigger debugger
    // breaks
    try {
      final response = await http
          .head(Uri.parse('https://www.google.com/favicon.ico'))
          .timeout(const Duration(milliseconds: 1500));

      final hasInternet = response.statusCode < 500;
      if (hasInternet) {
        _log('Internet connectivity test: connected');
      }
      return hasInternet;
    } on Exception {
      // All exceptions (SocketException, TimeoutException, etc.) are caught
      // silently. This is expected behavior when there's no internet - not an
      // error. Return false without logging to keep it completely silent.
      return false;
    }
  }

  /// Updates the connectivity state and notifies listeners
  void _updateConnectivityState(final ConnectivityState state) {
    if (_connectivityController.value != state) {
      _connectivityController.add(state);
      _onlineController.add(state.isConnected);
      _log('Connectivity state updated: $state');
    }
  }

  /// Expose connectivity state update
  @override
  void updateConnectivityState(final ConnectivityState state) {
    final previousState = _connectivityController.value;
    _log('updateConnectivityState called: $previousState -> $state');

    _updateConnectivityState(state);

    // If we just came back online, process the offline queue
    if (!previousState.isConnected && state.isConnected) {
      _log(
        'Device came back online via updateConnectivityState, processing '
        'offline queue',
      );
      unawaited(_processOfflineQueue());
    } else {
      _log(
        'No queue processing needed: previousState.isConnected='
        '${previousState.isConnected}, state.isConnected=${state.isConnected}',
      );
    }
  }

  /// Maps ConnectivityResult to ConnectivityState
  ConnectivityState _mapConnectivityResult(final ConnectivityResult result) {
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
  ConnectivityState mapConnectivityResult(final ConnectivityResult result) =>
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
          'Processing request: ${request.id} (retries: ${request.retryCount}/${request.maxRetries})',
        );

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

  /// Executes a network request using HTTP client
  Future<void> _executeRequest(final NetworkRequest request) async {
    _log('Executing request: ${request.method} ${request.url}');

    try {
      http.Response response;

      // Create URI from request URL
      final uri = Uri.parse(request.url);

      // Prepare headers
      final headers = <String, String>{...request.headers};

      // Use a reasonable timeout (30 seconds) for individual requests
      // This is separate from retry delays which happen between attempts
      const requestTimeout = Duration(seconds: 30);

      // Execute the request based on method
      switch (request.method.toUpperCase()) {
        case 'GET':
          response = await http
              .get(uri, headers: headers)
              .timeout(requestTimeout);
        case 'POST':
          response = await http
              .post(uri, headers: headers, body: request.body)
              .timeout(requestTimeout);
        case 'PUT':
          response = await http
              .put(uri, headers: headers, body: request.body)
              .timeout(requestTimeout);
        case 'PATCH':
          response = await http
              .patch(uri, headers: headers, body: request.body)
              .timeout(requestTimeout);
        case 'DELETE':
          response = await http
              .delete(uri, headers: headers)
              .timeout(requestTimeout);
        default:
          throw RequestExecutionException(
            request.id,
            'Unsupported HTTP method: ${request.method}',
          );
      }

      // Check if response indicates an error
      if (response.statusCode >= 400) {
        throw RequestExecutionException(
          request.id,
          'HTTP ${response.statusCode}: '
          '${response.reasonPhrase ?? "Request failed"}',
          response.statusCode,
        );
      }

      _log(
        'Request ${request.id} executed successfully: HTTP '
        '${response.statusCode}',
      );
    } on TimeoutException catch (e) {
      throw RequestExecutionException(
        request.id,
        'Request timeout: ${e.message}',
      );
    } on SocketException catch (e) {
      throw RequestExecutionException(
        request.id,
        'Network error: ${e.message}',
      );
    } on HttpException catch (e) {
      throw RequestExecutionException(request.id, 'HTTP error: ${e.message}');
    } on FormatException catch (e) {
      throw RequestExecutionException(
        request.id,
        'Invalid URL format: ${e.message}',
      );
    } on RequestExecutionException {
      // Re-throw RequestExecutionException as-is
      rethrow;
    } catch (e) {
      throw RequestExecutionException(request.id, 'Unexpected error: $e');
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
  void _log(final String message) {
    if (config.enableLogging && kDebugMode) {
      debugPrint('[NetworkWatcher] $message');
    }
  }
}
