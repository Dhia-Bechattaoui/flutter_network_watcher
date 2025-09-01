import 'package:flutter_network_watcher/src/models/network_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NetworkRequest', () {
    test('creates request with required parameters', () {
      final request = NetworkRequest(
        id: 'test_id',
        method: 'GET',
        url: 'https://example.com',
        createdAt: DateTime(2024, 1, 1, 12, 0, 0),
      );

      expect(request.id, equals('test_id'));
      expect(request.method, equals('GET'));
      expect(request.url, equals('https://example.com'));
      expect(request.createdAt, equals(DateTime(2024, 1, 1, 12, 0, 0)));
      expect(request.retryCount, equals(0));
      expect(request.maxRetries, equals(3));
      expect(request.priority, equals(0));
      expect(request.headers, isEmpty);
      expect(request.body, isNull);
      expect(request.metadata, isNull);
      expect(request.lastRetryTime, isNull);
      expect(request.retryDelay, isNull);
      expect(request.failureReason, isNull);
      expect(request.lastFailureStatusCode, isNull);
      expect(request.retryableErrorTypes,
          equals(['timeout', 'network_error', 'server_error']));
      expect(request.retryOnSpecificErrors, isFalse);
    });

    test('creates request with all parameters', () {
      final request = NetworkRequest(
        id: 'test_id',
        method: 'POST',
        url: 'https://example.com/api',
        headers: {'Content-Type': 'application/json'},
        body: 'test body',
        createdAt: DateTime(2024, 1, 1, 12, 0, 0),
        retryCount: 1,
        maxRetries: 5,
        priority: 10,
        metadata: {'key': 'value'},
        lastRetryTime: DateTime(2024, 1, 1, 12, 5, 0),
        retryDelay: 5000,
        failureReason: 'timeout',
        lastFailureStatusCode: 408,
        retryableErrorTypes: ['timeout'],
        retryOnSpecificErrors: true,
      );

      expect(request.id, equals('test_id'));
      expect(request.method, equals('POST'));
      expect(request.url, equals('https://example.com/api'));
      expect(request.headers, equals({'Content-Type': 'application/json'}));
      expect(request.body, equals('test body'));
      expect(request.createdAt, equals(DateTime(2024, 1, 1, 12, 0, 0)));
      expect(request.retryCount, equals(1));
      expect(request.maxRetries, equals(5));
      expect(request.priority, equals(10));
      expect(request.metadata, equals({'key': 'value'}));
      expect(request.lastRetryTime, equals(DateTime(2024, 1, 1, 12, 5, 0)));
      expect(request.retryDelay, equals(5000));
      expect(request.failureReason, equals('timeout'));
      expect(request.lastFailureStatusCode, equals(408));
      expect(request.retryableErrorTypes, equals(['timeout']));
      expect(request.retryOnSpecificErrors, isTrue);
    });

    test('copyWith creates new instance with updated values', () {
      final original = NetworkRequest(
        id: 'original',
        method: 'GET',
        url: 'https://example.com',
        createdAt: DateTime(2024, 1, 1, 12, 0, 0),
      );

      final updated = original.copyWith(
        method: 'POST',
        priority: 5,
        retryCount: 2,
        failureReason: 'server error',
        lastFailureStatusCode: 500,
      );

      expect(updated.id, equals('original'));
      expect(updated.method, equals('POST'));
      expect(updated.url, equals('https://example.com'));
      expect(updated.priority, equals(5));
      expect(updated.retryCount, equals(2));
      expect(updated.failureReason, equals('server error'));
      expect(updated.lastFailureStatusCode, equals(500));
      expect(updated.maxRetries, equals(3)); // unchanged
      expect(updated.createdAt,
          equals(DateTime(2024, 1, 1, 12, 0, 0))); // unchanged
    });

    test('canRetry returns true when retryCount is less than maxRetries', () {
      final request = NetworkRequest(
        id: 'test',
        method: 'GET',
        url: 'https://example.com',
        createdAt: DateTime.now(),
        retryCount: 2,
        maxRetries: 3,
      );

      expect(request.canRetry, isTrue);
    });

    test('canRetry returns false when retryCount equals maxRetries', () {
      final request = NetworkRequest(
        id: 'test',
        method: 'GET',
        url: 'https://example.com',
        createdAt: DateTime.now(),
        retryCount: 3,
        maxRetries: 3,
      );

      expect(request.canRetry, isFalse);
    });

    test('shouldRetryOnError returns true when retryOnSpecificErrors is false',
        () {
      final request = NetworkRequest(
        id: 'test',
        method: 'GET',
        url: 'https://example.com',
        createdAt: DateTime.now(),
        retryOnSpecificErrors: false,
      );

      expect(request.shouldRetryOnError('any_error'), isTrue);
    });

    test('shouldRetryOnError returns true for retryable error types', () {
      final request = NetworkRequest(
        id: 'test',
        method: 'GET',
        url: 'https://example.com',
        createdAt: DateTime.now(),
        retryOnSpecificErrors: true,
        retryableErrorTypes: ['timeout', 'server_error'],
      );

      expect(request.shouldRetryOnError('timeout'), isTrue);
      expect(request.shouldRetryOnError('server_error'), isTrue);
    });

    test('shouldRetryOnError returns false for non-retryable error types', () {
      final request = NetworkRequest(
        id: 'test',
        method: 'GET',
        url: 'https://example.com',
        createdAt: DateTime.now(),
        retryOnSpecificErrors: true,
        retryableErrorTypes: ['timeout', 'server_error'],
      );

      expect(request.shouldRetryOnError('client_error'), isFalse);
      expect(request.shouldRetryOnError('unknown_error'), isFalse);
    });

    test(
        'withIncrementedRetry creates new request with incremented retry count',
        () {
      final original = NetworkRequest(
        id: 'test',
        method: 'GET',
        url: 'https://example.com',
        createdAt: DateTime.now(),
        retryCount: 1,
        failureReason: 'old error',
      );

      final updated = original.withIncrementedRetry(
        failureReason: 'new error',
        statusCode: 500,
        retryDelay: 10000,
      );

      expect(updated.retryCount, equals(2));
      expect(updated.failureReason, equals('new error'));
      expect(updated.lastFailureStatusCode, equals(500));
      expect(updated.retryDelay, equals(10000));
      expect(updated.lastRetryTime, isNotNull);
      expect(updated.id, equals('test')); // unchanged
      expect(updated.method, equals('GET')); // unchanged
    });

    test('withFailureInfo creates new request with updated failure information',
        () {
      final original = NetworkRequest(
        id: 'test',
        method: 'GET',
        url: 'https://example.com',
        createdAt: DateTime.now(),
      );

      final updated = original.withFailureInfo(
        failureReason: 'connection timeout',
        statusCode: 408,
      );

      expect(updated.failureReason, equals('connection timeout'));
      expect(updated.lastFailureStatusCode, equals(408));
      expect(updated.id, equals('test')); // unchanged
      expect(updated.retryCount, equals(0)); // unchanged
    });

    test('toJson converts to correct JSON map', () {
      final request = NetworkRequest(
        id: 'test_id',
        method: 'POST',
        url: 'https://example.com/api',
        headers: {'Content-Type': 'application/json'},
        body: 'test body',
        createdAt: DateTime(2024, 1, 1, 12, 0, 0),
        retryCount: 1,
        maxRetries: 3,
        priority: 5,
        metadata: {'key': 'value'},
      );

      final json = request.toJson();

      expect(json['id'], equals('test_id'));
      expect(json['method'], equals('POST'));
      expect(json['url'], equals('https://example.com/api'));
      expect(json['headers'], equals({'Content-Type': 'application/json'}));
      expect(json['body'], equals('test body'));
      expect(json['createdAt'], equals('2024-01-01T12:00:00.000'));
      expect(json['retryCount'], equals(1));
      expect(json['maxRetries'], equals(3));
      expect(json['priority'], equals(5));
      expect(json['metadata'], equals({'key': 'value'}));
      expect(json['lastRetryTime'], isNull);
      expect(json['retryDelay'], isNull);
      expect(json['failureReason'], isNull);
      expect(json['lastFailureStatusCode'], isNull);
      expect(json['retryableErrorTypes'],
          equals(['timeout', 'network_error', 'server_error']));
      expect(json['retryOnSpecificErrors'], isFalse);
    });

    test('fromJson creates request from JSON map', () {
      final json = {
        'id': 'test_id',
        'method': 'POST',
        'url': 'https://example.com/api',
        'headers': {'Content-Type': 'application/json'},
        'body': 'test body',
        'createdAt': '2024-01-01T12:00:00.000',
        'retryCount': 1,
        'maxRetries': 3,
        'priority': 5,
        'metadata': {'key': 'value'},
        'lastRetryTime': '2024-01-01T12:05:00.000',
        'retryDelay': 5000,
        'failureReason': 'timeout',
        'lastFailureStatusCode': 408,
        'retryableErrorTypes': ['timeout'],
        'retryOnSpecificErrors': true,
      };

      final request = NetworkRequest.fromJson(json);

      expect(request.id, equals('test_id'));
      expect(request.method, equals('POST'));
      expect(request.url, equals('https://example.com/api'));
      expect(request.headers, equals({'Content-Type': 'application/json'}));
      expect(request.body, equals('test body'));
      expect(request.createdAt, equals(DateTime(2024, 1, 1, 12, 0, 0)));
      expect(request.retryCount, equals(1));
      expect(request.maxRetries, equals(3));
      expect(request.priority, equals(5));
      expect(request.metadata, equals({'key': 'value'}));
      expect(request.lastRetryTime, equals(DateTime(2024, 1, 1, 12, 5, 0)));
      expect(request.retryDelay, equals(5000));
      expect(request.failureReason, equals('timeout'));
      expect(request.lastFailureStatusCode, equals(408));
      expect(request.retryableErrorTypes, equals(['timeout']));
      expect(request.retryOnSpecificErrors, isTrue);
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 'test_id',
        'method': 'GET',
        'url': 'https://example.com',
        'headers': {},
        'createdAt': '2024-01-01T12:00:00.000',
      };

      final request = NetworkRequest.fromJson(json);

      expect(request.retryCount, equals(0));
      expect(request.maxRetries, equals(3));
      expect(request.priority, equals(0));
      expect(request.metadata, isNull);
      expect(request.lastRetryTime, isNull);
      expect(request.retryDelay, isNull);
      expect(request.failureReason, isNull);
      expect(request.lastFailureStatusCode, isNull);
      expect(request.retryableErrorTypes,
          equals(['timeout', 'network_error', 'server_error']));
      expect(request.retryOnSpecificErrors, isFalse);
    });

    test('toJsonString converts to JSON string', () {
      final request = NetworkRequest(
        id: 'test_id',
        method: 'GET',
        url: 'https://example.com',
        createdAt: DateTime(2024, 1, 1, 12, 0, 0),
      );

      final jsonString = request.toJsonString();
      final decoded = NetworkRequest.fromJsonString(jsonString);

      expect(decoded.id, equals('test_id'));
      expect(decoded.method, equals('GET'));
      expect(decoded.url, equals('https://example.com'));
    });

    test('fromJsonString creates request from JSON string', () {
      final jsonString = '''
        {
          "id": "test_id",
          "method": "GET",
          "url": "https://example.com",
          "headers": {},
          "createdAt": "2024-01-01T12:00:00.000",
          "retryCount": 0,
          "maxRetries": 3,
          "priority": 0
        }
      ''';

      final request = NetworkRequest.fromJsonString(jsonString);

      expect(request.id, equals('test_id'));
      expect(request.method, equals('GET'));
      expect(request.url, equals('https://example.com'));
    });

    test('toString includes key information', () {
      final request = NetworkRequest(
        id: 'test_id',
        method: 'POST',
        url: 'https://example.com/api',
        createdAt: DateTime.now(),
        retryCount: 2,
        failureReason: 'timeout',
      );

      final string = request.toString();

      expect(string, contains('test_id'));
      expect(string, contains('POST'));
      expect(string, contains('https://example.com/api'));
      expect(string, contains('2'));
      expect(string, contains('timeout'));
    });

    test('equality and hashCode work correctly', () {
      final request1 = NetworkRequest(
        id: 'same_id',
        method: 'GET',
        url: 'https://example.com',
        createdAt: DateTime.now(),
      );

      final request2 = NetworkRequest(
        id: 'same_id',
        method: 'POST', // different method
        url: 'https://different.com', // different URL
        createdAt: DateTime.now().add(Duration(hours: 1)), // different time
      );

      final request3 = NetworkRequest(
        id: 'different_id', // different ID
        method: 'GET',
        url: 'https://example.com',
        createdAt: DateTime.now(),
      );

      expect(request1, equals(request2)); // Same ID
      expect(request1, isNot(equals(request3))); // Different ID
      expect(request1.hashCode, equals(request2.hashCode));
      expect(request1.hashCode, isNot(equals(request3.hashCode)));
    });
  });
}
