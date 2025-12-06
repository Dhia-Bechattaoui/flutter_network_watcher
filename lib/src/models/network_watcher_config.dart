/// Configuration options for the NetworkWatcher
class NetworkWatcherConfig {
  /// Creates a new NetworkWatcherConfig
  const NetworkWatcherConfig({
    this.checkInterval = const Duration(seconds: 5),
    this.autoRetry = true,
    this.maxQueueSize = 100,
    this.persistQueue = true,
    this.maxRequestAge = const Duration(hours: 24),
    this.enableLogging = false,
    this.retryDelayStrategy,
    this.maxRetryDelay = const Duration(minutes: 5),
    this.retryJitter = true,
    this.deadLetterQueueEnabled = false,
    this.maxDeadLetterQueueSize = 50,
    this.retryableStatusCodes = const [408, 429, 500, 502, 503, 504],
    this.retryOnNetworkErrors = true,
    this.retryOnServerErrors = true,
    this.retryOnClientErrors = false,
  });

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

  /// Maximum retry delay (prevents excessive delays)
  final Duration maxRetryDelay;

  /// Whether to add jitter to retry delays (helps prevent thundering herd)
  final bool retryJitter;

  /// Whether to enable dead letter queue for failed requests
  final bool deadLetterQueueEnabled;

  /// Maximum size of the dead letter queue
  final int maxDeadLetterQueueSize;

  /// HTTP status codes that should trigger a retry
  final List<int> retryableStatusCodes;

  /// Whether to retry on network errors (timeouts, connection failures)
  final bool retryOnNetworkErrors;

  /// Whether to retry on server errors (5xx status codes)
  final bool retryOnServerErrors;

  /// Whether to retry on client errors (4xx status codes, except 4xx)
  final bool retryOnClientErrors;

  /// Default configuration
  static const NetworkWatcherConfig defaultConfig = NetworkWatcherConfig();

  /// Configuration optimized for minimal battery usage
  static const NetworkWatcherConfig batteryOptimized = NetworkWatcherConfig(
    checkInterval: Duration(seconds: 30),
    maxQueueSize: 50,
    maxRequestAge: Duration(hours: 6),
    maxRetryDelay: Duration(minutes: 2),
  );

  /// Configuration optimized for real-time responsiveness
  static const NetworkWatcherConfig realTime = NetworkWatcherConfig(
    checkInterval: Duration(seconds: 1),
    maxQueueSize: 200,
    enableLogging: true,
    maxRetryDelay: Duration(minutes: 1),
    retryJitter: false,
  );

  /// Configuration optimized for reliability with aggressive retries
  static const NetworkWatcherConfig reliabilityOptimized = NetworkWatcherConfig(
    checkInterval: Duration(seconds: 2),
    maxQueueSize: 300,
    maxRetryDelay: Duration(minutes: 10),
    deadLetterQueueEnabled: true,
    maxDeadLetterQueueSize: 100,
    retryOnClientErrors: true,
  );

  /// Creates a copy of this config with updated values
  NetworkWatcherConfig copyWith({
    final Duration? checkInterval,
    final bool? autoRetry,
    final int? maxQueueSize,
    final bool? persistQueue,
    final Duration? maxRequestAge,
    final bool? enableLogging,
    final Duration Function(int retryCount)? retryDelayStrategy,
    final Duration? maxRetryDelay,
    final bool? retryJitter,
    final bool? deadLetterQueueEnabled,
    final int? maxDeadLetterQueueSize,
    final List<int>? retryableStatusCodes,
    final bool? retryOnNetworkErrors,
    final bool? retryOnServerErrors,
    final bool? retryOnClientErrors,
  }) => NetworkWatcherConfig(
    checkInterval: checkInterval ?? this.checkInterval,
    autoRetry: autoRetry ?? this.autoRetry,
    maxQueueSize: maxQueueSize ?? this.maxQueueSize,
    persistQueue: persistQueue ?? this.persistQueue,
    maxRequestAge: maxRequestAge ?? this.maxRequestAge,
    enableLogging: enableLogging ?? this.enableLogging,
    retryDelayStrategy: retryDelayStrategy ?? this.retryDelayStrategy,
    maxRetryDelay: maxRetryDelay ?? this.maxRetryDelay,
    retryJitter: retryJitter ?? this.retryJitter,
    deadLetterQueueEnabled:
        deadLetterQueueEnabled ?? this.deadLetterQueueEnabled,
    maxDeadLetterQueueSize:
        maxDeadLetterQueueSize ?? this.maxDeadLetterQueueSize,
    retryableStatusCodes: retryableStatusCodes ?? this.retryableStatusCodes,
    retryOnNetworkErrors: retryOnNetworkErrors ?? this.retryOnNetworkErrors,
    retryOnServerErrors: retryOnServerErrors ?? this.retryOnServerErrors,
    retryOnClientErrors: retryOnClientErrors ?? this.retryOnClientErrors,
  );

  /// Default exponential backoff retry strategy
  static Duration defaultRetryDelay(final int retryCount) =>
      Duration(seconds: (2 * retryCount).clamp(1, 60));

  /// Linear retry delay strategy
  static Duration linearRetryDelay(final int retryCount) =>
      Duration(seconds: (5 * retryCount).clamp(5, 30));

  /// Fixed retry delay strategy
  static Duration fixedRetryDelay(final int retryCount) =>
      const Duration(seconds: 10);

  /// Exponential backoff with jitter strategy
  static Duration exponentialBackoffWithJitter(final int retryCount) {
    final baseDelay = Duration(seconds: (2 * retryCount).clamp(1, 60));
    final jitter = Duration(
      milliseconds: (baseDelay.inMilliseconds * 0.1).round(),
    );
    return Duration(
      milliseconds: baseDelay.inMilliseconds + jitter.inMilliseconds,
    );
  }

  /// Determines if a status code should trigger a retry
  bool shouldRetryOnStatusCode(final int statusCode) {
    if (retryableStatusCodes.contains(statusCode)) {
      return true;
    }

    if (statusCode >= 500 && statusCode < 600) {
      return retryOnServerErrors;
    }

    if (statusCode >= 400 && statusCode < 500) {
      return retryOnClientErrors;
    }

    return false;
  }

  @override
  String toString() =>
      'NetworkWatcherConfig{'
      'checkInterval: $checkInterval, '
      'autoRetry: $autoRetry, '
      'maxQueueSize: $maxQueueSize, '
      'persistQueue: $persistQueue, '
      'maxRequestAge: $maxRequestAge, '
      'enableLogging: $enableLogging, '
      'maxRetryDelay: $maxRetryDelay, '
      'retryJitter: $retryJitter, '
      'deadLetterQueueEnabled: $deadLetterQueueEnabled'
      '}';
}
