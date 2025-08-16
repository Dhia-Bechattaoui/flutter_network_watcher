import 'models/connectivity_state.dart';
import 'models/network_request.dart';
import 'models/network_watcher_config.dart';
import 'platform/network_watcher_platform.dart';

/// Main class for monitoring network connectivity and managing offline requests
class NetworkWatcher {
  /// Platform-specific implementation
  late final NetworkWatcherPlatform _platform;

  /// Configuration for the network watcher
  final NetworkWatcherConfig config;

  /// For testing: expose active state
  bool get isActive => _platform.isActive;

  /// Creates a new NetworkWatcher instance
  NetworkWatcher({
    this.config = NetworkWatcherConfig.defaultConfig,
  }) {
    _platform = NetworkWatcherPlatform(config: config);
  }

  /// Stream of connectivity state changes
  Stream<ConnectivityState> get connectivityStream =>
      _platform.connectivityStream;

  /// Stream of online/offline status changes
  Stream<bool> get onlineStream => _platform.onlineStream;

  /// Current connectivity state
  ConnectivityState get currentConnectivityState =>
      _platform.currentConnectivityState;

  /// Whether the device is currently online
  bool get isOnline => _platform.isOnline;

  /// Whether the device is currently offline
  bool get isOffline => _platform.isOffline;

  /// Number of requests currently in the offline queue
  int get queueSize => _platform.queueSize;

  /// List of all requests in the offline queue
  List<NetworkRequest> get queuedRequests => _platform.queuedRequests;

  /// Starts monitoring network connectivity
  Future<void> start() async => _platform.start();

  /// Stops monitoring network connectivity
  Future<void> stop() async => _platform.stop();

  /// Queues a network request for execution when online
  Future<void> queueRequest(NetworkRequest request) async =>
      _platform.queueRequest(request);

  /// Removes a specific request from the queue
  Future<bool> removeRequest(String requestId) async =>
      _platform.removeRequest(requestId);

  /// Clears all requests from the queue
  Future<void> clearQueue() async => _platform.clearQueue();

  /// Forces a connectivity check
  Future<void> checkConnectivity() async => _platform.checkConnectivity();

  /// Manually processes the offline queue
  Future<void> processQueue() async => _platform.processQueue();

  /// Disposes of all resources
  Future<void> dispose() async => _platform.dispose();

  /// For testing: expose connectivity state update
  void updateConnectivityState(ConnectivityState state) =>
      _platform.updateConnectivityState(state);
}
