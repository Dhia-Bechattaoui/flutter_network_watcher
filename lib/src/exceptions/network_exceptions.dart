/// Base class for all network watcher exceptions
abstract class NetworkWatcherException implements Exception {
  /// Error message
  final String message;

  /// Optional underlying cause
  final Object? cause;

  /// Creates a new NetworkWatcherException
  const NetworkWatcherException(this.message, [this.cause]);

  @override
  String toString() => 'NetworkWatcherException: $message';
}

/// Exception thrown when the offline queue is full
class QueueFullException extends NetworkWatcherException {
  /// Maximum queue size that was exceeded
  final int maxSize;

  /// Creates a new QueueFullException
  const QueueFullException(this.maxSize)
      : super('Offline queue is full (max size: $maxSize)');

  @override
  String toString() => 'QueueFullException: $message';
}

/// Exception thrown when a request fails to be queued
class QueueException extends NetworkWatcherException {
  /// Creates a new QueueException
  const QueueException(String message, [Object? cause]) : super(message, cause);

  @override
  String toString() => 'QueueException: $message';
}

/// Exception thrown when network request execution fails
class RequestExecutionException extends NetworkWatcherException {
  /// The request that failed
  final String requestId;

  /// HTTP status code (if applicable)
  final int? statusCode;

  /// Creates a new RequestExecutionException
  const RequestExecutionException(this.requestId, String message,
      [this.statusCode, Object? cause])
      : super(message, cause);

  @override
  String toString() =>
      'RequestExecutionException: $message (Request ID: $requestId)';
}

/// Exception thrown when network connectivity cannot be determined
class ConnectivityException extends NetworkWatcherException {
  /// Creates a new ConnectivityException
  const ConnectivityException(String message, [Object? cause])
      : super(message, cause);

  @override
  String toString() => 'ConnectivityException: $message';
}

/// Exception thrown when queue persistence operations fail
class PersistenceException extends NetworkWatcherException {
  /// Creates a new PersistenceException
  const PersistenceException(String message, [Object? cause])
      : super(message, cause);

  @override
  String toString() => 'PersistenceException: $message';
}
