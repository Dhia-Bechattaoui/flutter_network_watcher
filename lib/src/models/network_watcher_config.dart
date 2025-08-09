/// Configuration options for the NetworkWatcher
class NetworkWatcherConfig {
  /// How often to check connectivity when offline (in milliseconds)
  final Duration checkInterval;

  /// Whether to automatically retry failed requests when back online
  final bool autoRetry;

  /// Maximum number of requests to keep in the offline queue
  final int maxQueueSize;

  /// Whether to persist the queue across app sessions
  final bool persistQueue;

  /// Maximum age of requests in the queue before they're discarded
  final Duration maxRequestAge;

  /// Whether to enable debug logging
  final bool enableLogging;

  /// Custom retry delay strategy
  final Duration Function(int retryCount)? retryDelayStrategy;

  /// Creates a new NetworkWatcherConfig
  const NetworkWatcherConfig({
    this.checkInterval = const Duration(seconds: 5),
    this.autoRetry = true,
    this.maxQueueSize = 100,
    this.persistQueue = true,
    this.maxRequestAge = const Duration(hours: 24),
    this.enableLogging = false,
    this.retryDelayStrategy,
  });

  /// Default configuration
  static const NetworkWatcherConfig defaultConfig = NetworkWatcherConfig();

  /// Configuration optimized for minimal battery usage
  static const NetworkWatcherConfig batteryOptimized = NetworkWatcherConfig(
    checkInterval: Duration(seconds: 30),
    maxQueueSize: 50,
    maxRequestAge: Duration(hours: 6),
  );

  /// Configuration optimized for real-time responsiveness
  static const NetworkWatcherConfig realTime = NetworkWatcherConfig(
    checkInterval: Duration(seconds: 1),
    maxQueueSize: 200,
    enableLogging: true,
  );

  /// Creates a copy of this config with updated values
  NetworkWatcherConfig copyWith({
    Duration? checkInterval,
    bool? autoRetry,
    int? maxQueueSize,
    bool? persistQueue,
    Duration? maxRequestAge,
    bool? enableLogging,
    Duration Function(int retryCount)? retryDelayStrategy,
  }) {
    return NetworkWatcherConfig(
      checkInterval: checkInterval ?? this.checkInterval,
      autoRetry: autoRetry ?? this.autoRetry,
      maxQueueSize: maxQueueSize ?? this.maxQueueSize,
      persistQueue: persistQueue ?? this.persistQueue,
      maxRequestAge: maxRequestAge ?? this.maxRequestAge,
      enableLogging: enableLogging ?? this.enableLogging,
      retryDelayStrategy: retryDelayStrategy ?? this.retryDelayStrategy,
    );
  }

  /// Default exponential backoff retry strategy
  static Duration defaultRetryDelay(int retryCount) {
    return Duration(seconds: (2 * retryCount).clamp(1, 60));
  }

  /// Linear retry delay strategy
  static Duration linearRetryDelay(int retryCount) {
    return Duration(seconds: (5 * retryCount).clamp(5, 30));
  }

  /// Fixed retry delay strategy
  static Duration fixedRetryDelay(int retryCount) {
    return const Duration(seconds: 10);
  }

  @override
  String toString() {
    return 'NetworkWatcherConfig{'
        'checkInterval: $checkInterval, '
        'autoRetry: $autoRetry, '
        'maxQueueSize: $maxQueueSize, '
        'persistQueue: $persistQueue, '
        'maxRequestAge: $maxRequestAge, '
        'enableLogging: $enableLogging'
        '}';
  }
}
