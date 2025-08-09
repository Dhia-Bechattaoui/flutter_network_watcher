import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_network_watcher/src/models/network_request.dart';

void main() {
  group('NetworkRequest', () {
    late NetworkRequest testRequest;
    late DateTime testDateTime;

    setUp(() {
      testDateTime = DateTime(2024, 1, 1, 12, 0, 0);
      testRequest = NetworkRequest(
        id: 'test_id',
        method: 'POST',
        url: 'https://example.com/api',
        headers: {'Content-Type': 'application/json'},
        body: 'test body',
        createdAt: testDateTime,
        retryCount: 1,
        maxRetries: 3,
        priority: 5,
        metadata: {'key': 'value'},
      );
    });

    test('constructor creates request with all properties', () {
      expect(testRequest.id, equals('test_id'));
      expect(testRequest.method, equals('POST'));
      expect(testRequest.url, equals('https://example.com/api'));
      expect(testRequest.headers, equals({'Content-Type': 'application/json'}));
      expect(testRequest.body, equals('test body'));
      expect(testRequest.createdAt, equals(testDateTime));
      expect(testRequest.retryCount, equals(1));
      expect(testRequest.maxRetries, equals(3));
      expect(testRequest.priority, equals(5));
      expect(testRequest.metadata, equals({'key': 'value'}));
    });

    test('constructor with default values', () {
      final request = NetworkRequest(
        id: 'simple_id',
        method: 'GET',
        url: 'https://example.com',
        createdAt: testDateTime,
      );

      expect(request.headers, isEmpty);
      expect(request.body, isNull);
      expect(request.retryCount, equals(0));
      expect(request.maxRetries, equals(3));
      expect(request.priority, equals(0));
      expect(request.metadata, isNull);
    });

    test('copyWith creates new instance with updated values', () {
      final updated = testRequest.copyWith(
        method: 'GET',
        retryCount: 2,
        priority: 10,
      );

      expect(updated.id, equals('test_id')); // unchanged
      expect(updated.method, equals('GET')); // changed
      expect(updated.url, equals('https://example.com/api')); // unchanged
      expect(updated.retryCount, equals(2)); // changed
      expect(updated.priority, equals(10)); // changed
      expect(updated.maxRetries, equals(3)); // unchanged
    });

    test('canRetry returns correct value', () {
      expect(testRequest.canRetry, isTrue); // 1 < 3

      final maxedOut = testRequest.copyWith(retryCount: 3);
      expect(maxedOut.canRetry, isFalse); // 3 == 3

      final overMaxed = testRequest.copyWith(retryCount: 4);
      expect(overMaxed.canRetry, isFalse); // 4 > 3
    });

    test('withIncrementedRetry increments retry count', () {
      final incremented = testRequest.withIncrementedRetry();

      expect(incremented.retryCount, equals(2));
      expect(incremented.id, equals(testRequest.id));
      expect(incremented.method, equals(testRequest.method));
    });

    test('toJson converts to correct JSON map', () {
      final json = testRequest.toJson();

      expect(
          json,
          equals({
            'id': 'test_id',
            'method': 'POST',
            'url': 'https://example.com/api',
            'headers': {'Content-Type': 'application/json'},
            'body': 'test body',
            'createdAt': testDateTime.toIso8601String(),
            'retryCount': 1,
            'maxRetries': 3,
            'priority': 5,
            'metadata': {'key': 'value'},
          }));
    });

    test('fromJson creates request from JSON map', () {
      final json = {
        'id': 'json_id',
        'method': 'PUT',
        'url': 'https://example.com/put',
        'headers': {'Authorization': 'Bearer token'},
        'body': 'json body',
        'createdAt': testDateTime.toIso8601String(),
        'retryCount': 2,
        'maxRetries': 5,
        'priority': 8,
        'metadata': {'type': 'test'},
      };

      final request = NetworkRequest.fromJson(json);

      expect(request.id, equals('json_id'));
      expect(request.method, equals('PUT'));
      expect(request.url, equals('https://example.com/put'));
      expect(request.headers, equals({'Authorization': 'Bearer token'}));
      expect(request.body, equals('json body'));
      expect(request.createdAt, equals(testDateTime));
      expect(request.retryCount, equals(2));
      expect(request.maxRetries, equals(5));
      expect(request.priority, equals(8));
      expect(request.metadata, equals({'type': 'test'}));
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 'minimal_id',
        'method': 'GET',
        'url': 'https://example.com',
        'headers': <String, String>{},
        'createdAt': testDateTime.toIso8601String(),
      };

      final request = NetworkRequest.fromJson(json);

      expect(request.body, isNull);
      expect(request.retryCount, equals(0));
      expect(request.maxRetries, equals(3));
      expect(request.priority, equals(0));
      expect(request.metadata, isNull);
    });

    test('toJsonString and fromJsonString work correctly', () {
      final jsonString = testRequest.toJsonString();
      final decoded = NetworkRequest.fromJsonString(jsonString);

      expect(decoded.id, equals(testRequest.id));
      expect(decoded.method, equals(testRequest.method));
      expect(decoded.url, equals(testRequest.url));
      expect(decoded.headers, equals(testRequest.headers));
      expect(decoded.body, equals(testRequest.body));
      expect(decoded.createdAt, equals(testRequest.createdAt));
      expect(decoded.retryCount, equals(testRequest.retryCount));
      expect(decoded.maxRetries, equals(testRequest.maxRetries));
      expect(decoded.priority, equals(testRequest.priority));
      expect(decoded.metadata, equals(testRequest.metadata));
    });

    test('toString returns correct format', () {
      final string = testRequest.toString();
      expect(string, contains('NetworkRequest'));
      expect(string, contains('test_id'));
      expect(string, contains('POST'));
      expect(string, contains('https://example.com/api'));
      expect(string, contains('retryCount: 1'));
    });

    test('equality works correctly', () {
      final same = NetworkRequest(
        id: 'test_id',
        method: 'GET', // different method
        url: 'https://different.com', // different URL
        createdAt: DateTime.now(), // different time
      );

      final different = NetworkRequest(
        id: 'different_id',
        method: 'POST',
        url: 'https://example.com/api',
        createdAt: testDateTime,
      );

      expect(testRequest == same, isTrue); // same ID
      expect(testRequest == different, isFalse); // different ID
      expect(testRequest.hashCode, equals(same.hashCode));
      expect(testRequest.hashCode, isNot(equals(different.hashCode)));
    });
  });
}
