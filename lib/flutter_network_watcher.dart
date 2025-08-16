/// Flutter Network Watcher
///
/// Real-time network connectivity monitoring with offline queue management
/// for Flutter applications. Provides seamless network state tracking and
/// automatic request queuing during offline periods.
///
/// This library exports all the necessary components for network monitoring:
/// - NetworkWatcher - Main class for connectivity monitoring
/// - OfflineQueue - Queue management for offline requests
/// - NetworkRequest - Model for network requests
/// - ConnectivityState - Network connection state enumeration
/// - NetworkWatcherConfig - Configuration options
/// - Exception classes for error handling
library flutter_network_watcher;

export 'src/exceptions/network_exceptions.dart';
export 'src/models/connectivity_state.dart';
export 'src/models/network_request.dart';
export 'src/models/network_watcher_config.dart';
export 'src/network_watcher.dart';
export 'src/offline_queue.dart';
