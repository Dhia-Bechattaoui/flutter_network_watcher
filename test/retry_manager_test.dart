import 'package:flutter_network_watcher/src/exceptions/network_exceptions.dart';
import 'package:flutter_network_watcher/src/models/network_request.dart';
import 'package:flutter_network_watcher/src/models/network_watcher_config.dart';
import 'package:flutter_network_watcher/src/retry_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RetryManager', () {
    late RetryManager retryManager;
    late NetworkWatcherConfig config;

    setUp(() {
      config = const NetworkWatcherConfig(
        maxRetryDelay: Duration(minutes: 5),
        retryJitter: true,
        retryableStatusCodes: [408, 429, 500, 502, 503, 504],
        retryOnNetworkErrors: true,
        retryOnServerErrors: true,
        retryOnClientErrors: false,
        deadLetterQueueEnabled: true, // Enable dead letter queue for tests
      );
      retryManager = RetryManager(config: config);
    });

    group('shouldRetry', () {
      test('returns false when request has exceeded max retries', () {
        final request = NetworkRequest(
          id: 'test',
          method: 'GET',
          url: 'https://example.com',
          createdAt: DateTime.now(),
          retryCount: 3,
          maxRetries: 3,
        );

        final result = retryManager.shouldRetry(request, 'error');
        expect(result, isFalse);
      });

      test('returns true when request can be retried', () {
        final request = NetworkRequest(
          id: 'test',
          method: 'GET',
          url: 'https://example.com',
          createdAt: DateTime.now(),
          retryCount: 1,
          maxRetries: 3,
        );

        final result = retryManager.shouldRetry(request, 'timeout');
        expect(result, isTrue);
      });

      test('respects retryOnSpecificErrors when enabled', () {
        final request = NetworkRequest(
          id: 'test',
          method: 'GET',
          url: 'https://example.com',
          createdAt: DateTime.now(),
          retryOnSpecificErrors: true,
          retryableErrorTypes: ['timeout'],
        );

        final result = retryManager.shouldRetry(request, 'timeout');
        expect(result, isTrue);

        final result2 = retryManager.shouldRetry(request, 'client_error');
        expect(result2, isFalse);
      });

      test('retries on retryable status codes', () {
        final request = NetworkRequest(
          id: 'test',
          method: 'GET',
          url: 'https://example.com',
          createdAt: DateTime.now(),
        );

        expect(retryManager.shouldRetry(request, 'error', 500), isTrue);
        expect(retryManager.shouldRetry(request, 'error', 429), isTrue);
        expect(retryManager.shouldRetry(request, 'error', 404), isFalse);
      });

      test('retries on server errors when enabled', () {
        final request = NetworkRequest(
          id: 'test',
          method: 'GET',
          url: 'https://example.com',
          createdAt: DateTime.now(),
        );

        expect(retryManager.shouldRetry(request, 'error', 500), isTrue);
        expect(retryManager.shouldRetry(request, 'error', 502), isTrue);
      });

      test('does not retry on client errors when disabled', () {
        final request = NetworkRequest(
          id: 'test',
          method: 'GET',
          url: 'https://example.com',
          createdAt: DateTime.now(),
        );

        expect(retryManager.shouldRetry(request, 'error', 400), isFalse);
        expect(retryManager.shouldRetry(request, 'error', 403), isFalse);
      });

      test('retries on network errors when enabled', () {
        final request = NetworkRequest(
          id: 'test',
          method: 'GET',
          url: 'https://example.com',
          createdAt: DateTime.now(),
        );

        expect(retryManager.shouldRetry(request, 'timeout'), isTrue);
        expect(retryManager.shouldRetry(request, 'connection_error'), isTrue);
        expect(retryManager.shouldRetry(request, 'network_error'), isTrue);
        expect(retryManager.shouldRetry(request, 'unknown_error'), isFalse);
      });
    });

    group('calculateRetryDelay', () {
      test('uses custom retry delay strategy when provided', () {
        final customConfig = config.copyWith(
          retryDelayStrategy: (retryCount) =>
              Duration(seconds: retryCount * 10),
          retryJitter: false, // Disable jitter for deterministic test
        );
        final customRetryManager = RetryManager(config: customConfig);

        final request = NetworkRequest(
          id: 'test',
          method: 'GET',
          url: 'https://example.com',
          createdAt: DateTime.now(),
          retryCount: 2,
        );

        final delay = customRetryManager.calculateRetryDelay(request);
        expect(delay.inSeconds, equals(20));
      });

      test('uses default exponential backoff when no custom strategy', () {
        final noJitterConfig = config.copyWith(retryJitter: false);
        final noJitterRetryManager = RetryManager(config: noJitterConfig);

        final request = NetworkRequest(
          id: 'test',
          method: 'GET',
          url: 'https://example.com',
          createdAt: DateTime.now(),
          retryCount: 2,
        );

        final delay = noJitterRetryManager.calculateRetryDelay(request);
        expect(delay.inSeconds, equals(4)); // 2 * retryCount
      });

      test('caps delay at maximum allowed', () {
        final customConfig = config.copyWith(
          retryDelayStrategy: (retryCount) =>
              Duration(seconds: retryCount * 100), // Strategy that exceeds max
          retryJitter: false, // Disable jitter for deterministic test
        );
        final customRetryManager = RetryManager(config: customConfig);

        final request = NetworkRequest(
          id: 'test',
          method: 'GET',
          url: 'https://example.com',
          createdAt: DateTime.now(),
          retryCount: 10, // High enough to exceed max delay
        );

        final delay = customRetryManager.calculateRetryDelay(request);
        expect(delay, equals(config.maxRetryDelay));
      });

      test('adds jitter when enabled', () {
        final request = NetworkRequest(
          id: 'test',
          method: 'GET',
          url: 'https://example.com',
          createdAt: DateTime.now(),
          retryCount: 2,
        );

        final delay1 = retryManager.calculateRetryDelay(request);
        final delay2 = retryManager.calculateRetryDelay(request);

        // Delays should be different due to jitter
        expect(delay1, isNot(equals(delay2)));
      });
    });

    group('prepareForRetry', () {
      test('increments retry count and updates retry info', () {
        final request = NetworkRequest(
          id: 'test',
          method: 'GET',
          url: 'https://example.com',
          createdAt: DateTime.now(),
          retryCount: 1,
        );

        final retryRequest = retryManager.prepareForRetry(
          request,
          'timeout error',
          408,
        );

        expect(retryRequest.retryCount, equals(2));
        expect(retryRequest.lastRetryTime, isNotNull);
        expect(retryRequest.failureReason, contains('408'));
        expect(retryRequest.retryDelay, isNotNull);
      });

      test('handles RequestExecutionException correctly', () {
        final request = NetworkRequest(
          id: 'test',
          method: 'GET',
          url: 'https://example.com',
          createdAt: DateTime.now(),
        );

        final exception =
            RequestExecutionException('test', 'execution failed', 500);
        final retryRequest = retryManager.prepareForRetry(request, exception);

        expect(retryRequest.failureReason, contains('500'));
      });
    });

    group('getRetryStats', () {
      test('returns correct retry statistics', () {
        final now = DateTime.now();
        final request = NetworkRequest(
          id: 'test',
          method: 'GET',
          url: 'https://example.com',
          createdAt: now,
          retryCount: 2,
          maxRetries: 3,
          lastRetryTime: now.subtract(const Duration(minutes: 5)),
          failureReason: 'timeout',
          lastFailureStatusCode: 408,
        );

        final stats = retryManager.getRetryStats(request);

        expect(stats['retryCount'], equals(2));
        expect(stats['maxRetries'], equals(3));
        expect(stats['canRetry'], isTrue);
        expect(stats['failureReason'], equals('timeout'));
        expect(stats['lastFailureStatusCode'], equals(408));
        expect(stats['nextRetryDelay'], isNotNull);
      });

      test('handles request without retry history', () {
        final request = NetworkRequest(
          id: 'test',
          method: 'GET',
          url: 'https://example.com',
          createdAt: DateTime.now(),
        );

        final stats = retryManager.getRetryStats(request);

        expect(stats['retryCount'], equals(0));
        expect(stats['canRetry'], isTrue);
        expect(stats['lastRetryTime'], isNull);
      });
    });

    group('shouldMoveToDeadLetter', () {
      test('returns true when max retries exceeded', () {
        final request = NetworkRequest(
          id: 'test',
          method: 'GET',
          url: 'https://example.com',
          createdAt: DateTime.now(),
          retryCount: 3,
          maxRetries: 3,
        );

        final result = retryManager.shouldMoveToDeadLetter(request);
        expect(result, isTrue);
      });

      test('returns true when request is too old', () {
        final request = NetworkRequest(
          id: 'test',
          method: 'GET',
          url: 'https://example.com',
          createdAt: DateTime.now().subtract(const Duration(hours: 25)),
        );

        final result = retryManager.shouldMoveToDeadLetter(request);
        expect(result, isTrue);
      });

      test('returns false when request can still be retried and is not too old',
          () {
        final request = NetworkRequest(
          id: 'test',
          method: 'GET',
          url: 'https://example.com',
          createdAt: DateTime.now(),
          retryCount: 1,
          maxRetries: 3,
        );

        final result = retryManager.shouldMoveToDeadLetter(request);
        expect(result, isFalse);
      });
    });

    group('error classification', () {
      test('classifies HTTP status codes correctly', () {
        final request = NetworkRequest(
          id: 'test',
          method: 'GET',
          url: 'https://example.com',
          createdAt: DateTime.now(),
        );

        expect(retryManager.shouldRetry(request, 'error', 500), isTrue);
        expect(retryManager.shouldRetry(request, 'error', 400), isFalse);
        expect(retryManager.shouldRetry(request, 'error', 200), isFalse);
      });

      test('classifies error strings correctly', () {
        final request = NetworkRequest(
          id: 'test',
          method: 'GET',
          url: 'https://example.com',
          createdAt: DateTime.now(),
        );

        expect(retryManager.shouldRetry(request, 'timeout error'), isTrue);
        expect(retryManager.shouldRetry(request, 'connection failed'), isTrue);
        expect(
            retryManager.shouldRetry(request, 'network unavailable'), isTrue);
      });
    });
  });
}
