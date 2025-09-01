import '../dead_letter_queue.dart';
import '../models/connectivity_state.dart';
import '../models/network_request.dart';
import '../models/network_watcher_config.dart';

/// Abstract base class for platform-specific network watcher implementations
abstract class NetworkWatcherBase {
  /// Configuration for the network watcher
  NetworkWatcherConfig get config;

  /// Whether the watcher is currently active
  bool get isActive;

  /// Stream of connectivity state changes
  Stream<ConnectivityState> get connectivityStream;

  /// Stream of online/offline status changes
  Stream<bool> get onlineStream;

  /// Current connectivity state
  ConnectivityState get currentConnectivityState;

  /// Whether the device is currently online
  bool get isOnline;

  /// Whether the device is currently offline
  bool get isOffline;

  /// Number of requests currently in the offline queue
  int get queueSize;

  /// List of all requests in the offline queue
  List<NetworkRequest> get queuedRequests;

  /// Number of requests in the dead letter queue
  int get deadLetterQueueSize;

  /// Starts monitoring network connectivity
  Future<void> start();

  /// Stops monitoring network connectivity
  Future<void> stop();

  /// Queues a network request for execution when online
  Future<void> queueRequest(NetworkRequest request);

  /// Removes a specific request from the queue
  Future<bool> removeRequest(String requestId);

  /// Clears all requests from the queue
  Future<void> clearQueue();

  /// Forces a connectivity check
  Future<void> checkConnectivity();

  /// Manually processes the offline queue
  Future<void> processQueue();

  /// Gets retry statistics for a specific request
  Map<String, dynamic> getRetryStats(String requestId);

  /// Gets all requests that are ready for retry
  List<NetworkRequest> getRequestsReadyForRetry();

  /// Gets comprehensive queue statistics
  Map<String, dynamic> getQueueStatistics();

  /// Gets dead letter queue if enabled
  DeadLetterQueue? get deadLetterQueue;

  /// Disposes of all resources
  Future<void> dispose();

  /// For testing: expose connectivity state update
  void updateConnectivityState(ConnectivityState state);
}
