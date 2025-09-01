import 'dart:math';

import 'models/network_request.dart';
import 'models/network_watcher_config.dart';
import 'exceptions/network_exceptions.dart';

/// Manages retry logic for network requests
class RetryManager {
  /// Configuration for retry behavior
  final NetworkWatcherConfig config;

  /// Random number generator for jitter
  final Random _random = Random();

  /// Creates a new RetryManager
  RetryManager({required this.config});

  /// Determines if a request should be retried based on the error
  bool shouldRetry(NetworkRequest request, Object error, [int? statusCode]) {
    // Check if request has exceeded max retries
    if (!request.canRetry) {
      return false;
    }

    // Check if request should be retried based on error type
    if (request.retryOnSpecificErrors) {
      final errorType = _classifyError(error, statusCode);
      if (!request.shouldRetryOnError(errorType)) {
        return false;
      }
    }

    // Check status code if provided
    if (statusCode != null) {
      return config.shouldRetryOnStatusCode(statusCode);
    }

    // Check error type for network errors
    if (config.retryOnNetworkErrors) {
      final errorType = _classifyError(error, statusCode);
      return _isRetryableNetworkError(errorType);
    }

    // If no specific conditions are met, allow retry by default
    return true;
  }

  /// Calculates the retry delay for a request
  Duration calculateRetryDelay(NetworkRequest request) {
    Duration delay;

    // Use custom strategy if provided
    if (config.retryDelayStrategy != null) {
      delay = config.retryDelayStrategy!(request.retryCount);
    } else {
      // Use default exponential backoff
      delay = NetworkWatcherConfig.defaultRetryDelay(request.retryCount);
    }

    // Apply jitter if enabled
    if (config.retryJitter) {
      delay = _addJitter(delay);
    }

    // Cap the delay at maximum allowed
    if (delay > config.maxRetryDelay) {
      delay = config.maxRetryDelay;
    }

    return delay;
  }

  /// Creates a new request with updated retry information
  NetworkRequest prepareForRetry(
    NetworkRequest request,
    Object error, [
    int? statusCode,
  ]) {
    final delay = calculateRetryDelay(request);

    // Extract status code from RequestExecutionException if not provided
    final effectiveStatusCode = statusCode ??
        (error is RequestExecutionException ? error.statusCode : null);

    return request.withIncrementedRetry(
      failureReason: _getFailureReason(error, effectiveStatusCode),
      statusCode: effectiveStatusCode,
      retryDelay: delay.inMilliseconds,
    );
  }

  /// Classifies an error into a standard error type
  String _classifyError(Object error, int? statusCode) {
    if (statusCode != null) {
      if (statusCode >= 500) return 'server_error';
      if (statusCode >= 400) return 'client_error';
      if (statusCode >= 300) return 'redirect';
      if (statusCode >= 200) return 'success';
      if (statusCode >= 100) return 'informational';
    }

    if (error is RequestExecutionException) {
      if (error.statusCode != null) {
        return _classifyError(error, error.statusCode);
      }
      return 'execution_error';
    }

    if (error.toString().toLowerCase().contains('timeout')) {
      return 'timeout';
    }

    if (error.toString().toLowerCase().contains('connection')) {
      return 'connection_error';
    }

    if (error.toString().toLowerCase().contains('network')) {
      return 'network_error';
    }

    return 'unknown_error';
  }

  /// Determines if a network error type is retryable
  bool _isRetryableNetworkError(String errorType) {
    const retryableTypes = [
      'timeout',
      'connection_error',
      'network_error',
      'server_error',
      'execution_error',
    ];
    return retryableTypes.contains(errorType);
  }

  /// Adds jitter to a delay to prevent thundering herd
  Duration _addJitter(Duration delay) {
    final jitterFactor = 0.1; // 10% jitter
    final jitterMs = (delay.inMilliseconds * jitterFactor).round();
    final actualJitter = _random.nextInt(jitterMs * 2) - jitterMs;

    return Duration(milliseconds: delay.inMilliseconds + actualJitter);
  }

  /// Gets a human-readable failure reason
  String _getFailureReason(Object error, int? statusCode) {
    if (statusCode != null) {
      return 'HTTP $statusCode: ${_getStatusMessage(statusCode)}';
    }

    if (error is RequestExecutionException) {
      return error.message;
    }

    return error.toString();
  }

  /// Gets a human-readable message for HTTP status codes
  String _getStatusMessage(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Bad Request';
      case 401:
        return 'Unauthorized';
      case 403:
        return 'Forbidden';
      case 404:
        return 'Not Found';
      case 408:
        return 'Request Timeout';
      case 429:
        return 'Too Many Requests';
      case 500:
        return 'Internal Server Error';
      case 502:
        return 'Bad Gateway';
      case 503:
        return 'Service Unavailable';
      case 504:
        return 'Gateway Timeout';
      default:
        if (statusCode >= 500) {
          return 'Server Error';
        }
        if (statusCode >= 400) {
          return 'Client Error';
        }
        if (statusCode >= 300) {
          return 'Redirect';
        }
        if (statusCode >= 200) {
          return 'Success';
        }
        return 'Unknown Status';
    }
  }

  /// Gets retry statistics for a request
  Map<String, dynamic> getRetryStats(NetworkRequest request) {
    final now = DateTime.now();
    final lastRetry = request.lastRetryTime;

    return {
      'retryCount': request.retryCount,
      'maxRetries': request.maxRetries,
      'canRetry': request.canRetry,
      'lastRetryTime': lastRetry?.toIso8601String(),
      'timeSinceLastRetry':
          lastRetry != null ? now.difference(lastRetry).inSeconds : null,
      'nextRetryDelay':
          request.canRetry ? calculateRetryDelay(request).inMilliseconds : null,
      'failureReason': request.failureReason,
      'lastFailureStatusCode': request.lastFailureStatusCode,
    };
  }

  /// Determines if a request should be moved to dead letter queue
  bool shouldMoveToDeadLetter(NetworkRequest request) {
    if (!config.deadLetterQueueEnabled) {
      return false;
    }

    // Move to dead letter if max retries exceeded
    if (!request.canRetry) {
      return true;
    }

    // Move to dead letter if request is too old
    final age = DateTime.now().difference(request.createdAt);
    if (age > config.maxRequestAge) {
      return true;
    }

    return false;
  }
}
