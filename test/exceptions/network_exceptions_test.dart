import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_network_watcher/src/exceptions/network_exceptions.dart';

void main() {
  group('NetworkWatcherException', () {
    test('base exception has message and optional cause', () {
      const exception = TestNetworkWatcherException('Test message');

      expect(exception.message, equals('Test message'));
      expect(exception.cause, isNull);
      expect(exception.toString(),
          equals('NetworkWatcherException: Test message'));
    });

    test('base exception with cause', () {
      final originalError = Exception('Original error');
      final exception =
          TestNetworkWatcherException('Test message', originalError);

      expect(exception.message, equals('Test message'));
      expect(exception.cause, equals(originalError));
    });
  });

  group('QueueFullException', () {
    test('creates exception with max size', () {
      const exception = QueueFullException(100);

      expect(exception.maxSize, equals(100));
      expect(
          exception.message, equals('Offline queue is full (max size: 100)'));
      expect(exception.cause, isNull);
      expect(exception.toString(),
          equals('QueueFullException: Offline queue is full (max size: 100)'));
    });
  });

  group('QueueException', () {
    test('creates exception with message only', () {
      const exception = QueueException('Queue error occurred');

      expect(exception.message, equals('Queue error occurred'));
      expect(exception.cause, isNull);
      expect(
          exception.toString(), equals('QueueException: Queue error occurred'));
    });

    test('creates exception with message and cause', () {
      final originalError = Exception('Original error');
      final exception = QueueException('Queue error occurred', originalError);

      expect(exception.message, equals('Queue error occurred'));
      expect(exception.cause, equals(originalError));
      expect(
          exception.toString(), equals('QueueException: Queue error occurred'));
    });
  });

  group('RequestExecutionException', () {
    test('creates exception with request ID and message', () {
      const exception = RequestExecutionException('req_123', 'Request failed');

      expect(exception.requestId, equals('req_123'));
      expect(exception.message, equals('Request failed'));
      expect(exception.statusCode, isNull);
      expect(exception.cause, isNull);
      expect(
          exception.toString(),
          equals(
              'RequestExecutionException: Request failed (Request ID: req_123)'));
    });

    test('creates exception with all parameters', () {
      final originalError = Exception('Network error');
      final exception = RequestExecutionException(
          'req_456', 'Server error', 500, originalError);

      expect(exception.requestId, equals('req_456'));
      expect(exception.message, equals('Server error'));
      expect(exception.statusCode, equals(500));
      expect(exception.cause, equals(originalError));
      expect(
          exception.toString(),
          equals(
              'RequestExecutionException: Server error (Request ID: req_456)'));
    });
  });

  group('ConnectivityException', () {
    test('creates exception with message only', () {
      const exception = ConnectivityException('Connectivity check failed');

      expect(exception.message, equals('Connectivity check failed'));
      expect(exception.cause, isNull);
      expect(exception.toString(),
          equals('ConnectivityException: Connectivity check failed'));
    });

    test('creates exception with message and cause', () {
      final originalError = Exception('Platform error');
      final exception =
          ConnectivityException('Connectivity check failed', originalError);

      expect(exception.message, equals('Connectivity check failed'));
      expect(exception.cause, equals(originalError));
      expect(exception.toString(),
          equals('ConnectivityException: Connectivity check failed'));
    });
  });

  group('PersistenceException', () {
    test('creates exception with message only', () {
      const exception = PersistenceException('Failed to save data');

      expect(exception.message, equals('Failed to save data'));
      expect(exception.cause, isNull);
      expect(exception.toString(),
          equals('PersistenceException: Failed to save data'));
    });

    test('creates exception with message and cause', () {
      final originalError = Exception('Storage error');
      final exception =
          PersistenceException('Failed to save data', originalError);

      expect(exception.message, equals('Failed to save data'));
      expect(exception.cause, equals(originalError));
      expect(exception.toString(),
          equals('PersistenceException: Failed to save data'));
    });
  });
}

// Test implementation of abstract base class
class TestNetworkWatcherException extends NetworkWatcherException {
  const TestNetworkWatcherException(String message, [Object? cause])
      : super(message, cause);
}
