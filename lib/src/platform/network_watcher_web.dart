import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:rxdart/rxdart.dart';

import '../dead_letter_queue.dart';
import '../exceptions/network_exceptions.dart';
import '../models/connectivity_state.dart';
import '../models/network_request.dart';
import '../models/network_watcher_config.dart';
import '../offline_queue.dart';
import '../retry_manager.dart';
import 'network_watcher_base.dart';

/// Web platform implementation of NetworkWatcher
class NetworkWatcherPlatform extends NetworkWatcherBase {
  NetworkWatcherPlatform({this.config = NetworkWatcherConfig.defaultConfig}) {
    _connectivitySubject = BehaviorSubject.seeded(ConnectivityState.unknown);
    _onlineSubject = BehaviorSubject.seeded(false);

    _retryManager = RetryManager(config: config);
    _offlineQueue = OfflineQueue(config: config);

    if (config.deadLetterQueueEnabled) {
      _deadLetterQueue = DeadLetterQueue(config: config);
    }

    // Listen to online/offline events using periodic connectivity checks
    _onlineSubscription = _createOnlineStream().listen(_handleOnlineChange);

    // Check initial connectivity immediately
    unawaited(_checkInternetConnectivity().then(_handleOnlineChange));
  }
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

  /// Creates a stream that monitors online/offline status
  /// Uses periodic internet connectivity checks
  Stream<bool> _createOnlineStream() => Stream.periodic(
    const Duration(seconds: 3),
    (_) async => _checkInternetConnectivity(),
  ).asyncMap((final future) => future);

  /// Handles online/offline status changes
  void _handleOnlineChange(final bool isOnline) {
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
    if (_isActive) {
      return;
    }

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
    if (!_isActive) {
      return;
    }

    _isActive = false;

    _queueProcessingTimer?.cancel();
    _queueProcessingTimer = null;

    _log('Network watcher stopped');
  }

  @override
  Future<void> queueRequest(final NetworkRequest request) async {
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
  Future<bool> removeRequest(final String requestId) async =>
      _offlineQueue.remove(requestId);

  @override
  Future<void> clearQueue() async {
    await _offlineQueue.clear();
    _log('Queue cleared');
  }

  @override
  Future<void> checkConnectivity() async {
    try {
      _log('[NetworkWatcherPlatform] Checking connectivity...');

      // Check actual internet connectivity with HTTP request
      final hasInternet = await _checkInternetConnectivity();

      _log('[NetworkWatcherPlatform] Internet connectivity: $hasInternet');

      if (!hasInternet) {
        _log('[NetworkWatcherPlatform] No internet - setting offline');
        _connectivitySubject.add(ConnectivityState.none);
        _onlineSubject.add(false);
      } else {
        _log('[NetworkWatcherPlatform] Internet available - setting online');
        _connectivitySubject.add(ConnectivityState.wifi);
        _onlineSubject.add(true);
      }
    } on Exception catch (e) {
      _log('[NetworkWatcherPlatform] Error checking connectivity: $e');
      _connectivitySubject.add(ConnectivityState.unknown);
      _onlineSubject.add(false);
    }
  }

  /// Performs an actual internet connectivity test for web
  Future<bool> _checkInternetConnectivity() async {
    try {
      _log('[NetworkWatcherPlatform] Testing internet connectivity...');
      // Use HTTP HEAD request to check connectivity (faster than GET)
      final response = await http
          .head(Uri.parse('https://www.google.com/favicon.ico'))
          .timeout(const Duration(seconds: 2));

      final hasInternet = response.statusCode < 500;
      _log(
        '[NetworkWatcherPlatform] Internet test result: $hasInternet '
        '(status: ${response.statusCode})',
      );
      return hasInternet;
    } on Exception catch (e) {
      _log('[NetworkWatcherPlatform] Internet connectivity test failed: $e');
      return false;
    }
  }

  @override
  Future<void> processQueue() async {
    if (!_isActive || isOffline) {
      return;
    }

    _log('Processing offline queue (${_offlineQueue.size} requests)');

    final requestsToProcess = _offlineQueue.getRequestsReadyForRetry();
    if (requestsToProcess.isEmpty) {
      return;
    }

    for (final request in requestsToProcess) {
      try {
        await _executeRequest(request);
        await _offlineQueue.remove(request.id);
        _log('Request ${request.id} executed successfully');
      } on Exception catch (e) {
        _log('Request ${request.id} failed: $e');
        await _handleFailedRequest(request, e);
      }
    }

    // Clean up expired requests
    _cleanupExpiredRequests();
  }

  @override
  Map<String, dynamic> getRetryStats(final String requestId) {
    final request = _offlineQueue.getRequest(requestId);
    if (request == null) {
      return {};
    }
    return _retryManager.getRetryStats(request);
  }

  @override
  List<NetworkRequest> getRequestsReadyForRetry() =>
      _offlineQueue.getRequestsReadyForRetry();

  @override
  Map<String, dynamic> getQueueStatistics() {
    final baseStats = _offlineQueue.getStatistics();
    final dlqStats = _deadLetterQueue?.getStatistics() ?? {};

    return {...baseStats, 'deadLetterQueueStats': dlqStats, 'platform': 'web'};
  }

  @override
  void updateConnectivityState(final ConnectivityState state) {
    _connectivitySubject.add(state);
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _offlineQueue.dispose();
    await _deadLetterQueue?.dispose();
    unawaited(_onlineSubscription.cancel());
    unawaited(_connectivitySubject.close());
    unawaited(_onlineSubject.close());
  }

  void _startQueueProcessingTimer() {
    _queueProcessingTimer?.cancel();
    _queueProcessingTimer = Timer.periodic(config.checkInterval, (_) {
      if (_isActive && isOnline) {
        unawaited(processQueue());
      }
    });
  }

  Future<void> _executeRequest(final NetworkRequest request) async {
    _log('Executing request: ${request.method} ${request.url}');

    try {
      http.Response response;

      // Create URI from request URL
      final uri = Uri.parse(request.url);

      // Prepare headers
      final headers = <String, String>{...request.headers};

      // Use a reasonable timeout (30 seconds) for individual requests
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

  Future<void> _handleFailedRequest(
    final NetworkRequest request,
    final Object error,
  ) async {
    if (_retryManager.shouldRetry(request, error)) {
      final updatedRequest = _retryManager.prepareForRetry(request, error);
      await _offlineQueue.update(updatedRequest);
      _log(
        'Request ${request.id} prepared for retry (attempt '
        '${updatedRequest.retryCount})',
      );
    } else if (_deadLetterQueue != null) {
      final retryStats = _retryManager.getRetryStats(request);
      final failureReason = retryStats['failureReason'] as String?;
      final failedRequest = request.withFailureInfo(
        failureReason: failureReason,
      );
      await _deadLetterQueue!.enqueue(failedRequest);
      await _offlineQueue.remove(request.id);
      _log(
        'Request ${request.id} moved to dead letter queue after '
        '${request.retryCount} retries',
      );
    } else {
      await _offlineQueue.remove(request.id);
      _log('Request ${request.id} removed after max retries exceeded');
    }
  }

  void _cleanupExpiredRequests() {
    final requests = _offlineQueue.getAllRequests();
    for (final request in requests) {
      if (!request.canRetry) {
        unawaited(_offlineQueue.remove(request.id));
        _log('Expired request ${request.id} removed');
      }
    }
  }

  void _log(final String message) {
    if (config.enableLogging && kDebugMode) {
      debugPrint('[NetworkWatcherPlatform] $message');
    }
  }
}
