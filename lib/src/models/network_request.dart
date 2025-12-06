import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Represents a network request that can be queued for offline execution
@immutable
class NetworkRequest {
  /// Creates a new network request
  const NetworkRequest({
    required this.id,
    required this.method,
    required this.url,
    required this.createdAt,
    this.headers = const {},
    this.body,
    this.retryCount = 0,
    this.maxRetries = 3,
    this.priority = 0,
    this.metadata,
    this.lastRetryTime,
    this.retryDelay,
    this.failureReason,
    this.lastFailureStatusCode,
    this.retryableErrorTypes = const [
      'timeout',
      'network_error',
      'server_error',
    ],
    this.retryOnSpecificErrors = false,
  });

  /// Creates a NetworkRequest from a JSON map
  factory NetworkRequest.fromJson(final Map<String, dynamic> json) =>
      NetworkRequest(
        id: json['id'] as String,
        method: json['method'] as String,
        url: json['url'] as String,
        headers: Map<String, String>.from(json['headers'] as Map),
        body: json['body'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        retryCount: json['retryCount'] as int? ?? 0,
        maxRetries: json['maxRetries'] as int? ?? 3,
        priority: json['priority'] as int? ?? 0,
        metadata: json['metadata'] as Map<String, dynamic>?,
        lastRetryTime: json['lastRetryTime'] != null
            ? DateTime.parse(json['lastRetryTime'] as String)
            : null,
        retryDelay: json['retryDelay'] as int?,
        failureReason: json['failureReason'] as String?,
        lastFailureStatusCode: json['lastFailureStatusCode'] as int?,
        retryableErrorTypes:
            (json['retryableErrorTypes'] as List<dynamic>?)?.cast<String>() ??
            ['timeout', 'network_error', 'server_error'],
        retryOnSpecificErrors: json['retryOnSpecificErrors'] as bool? ?? false,
      );

  /// Creates a NetworkRequest from a JSON string
  factory NetworkRequest.fromJsonString(final String jsonString) =>
      NetworkRequest.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);

  /// Unique identifier for this request
  final String id;

  /// HTTP method (GET, POST, PUT, DELETE, etc.)
  final String method;

  /// Request URL
  final String url;

  /// Request headers
  final Map<String, String> headers;

  /// Request body (optional)
  final String? body;

  /// Timestamp when the request was created
  final DateTime createdAt;

  /// Number of retry attempts made
  final int retryCount;

  /// Maximum number of retry attempts allowed
  final int maxRetries;

  /// Priority of the request (higher number = higher priority)
  final int priority;

  /// Optional metadata for the request
  final Map<String, dynamic>? metadata;

  /// Timestamp of the last retry attempt
  final DateTime? lastRetryTime;

  /// Current retry delay in milliseconds
  final int? retryDelay;

  /// Reason for the last failure
  final String? failureReason;

  /// HTTP status code of the last failure
  final int? lastFailureStatusCode;

  /// Types of errors that should trigger a retry
  final List<String> retryableErrorTypes;

  /// Whether this request should be retried on specific error types
  final bool retryOnSpecificErrors;

  /// Creates a copy of this request with updated values
  NetworkRequest copyWith({
    final String? id,
    final String? method,
    final String? url,
    final Map<String, String>? headers,
    final String? body,
    final DateTime? createdAt,
    final int? retryCount,
    final int? maxRetries,
    final int? priority,
    final Map<String, dynamic>? metadata,
    final DateTime? lastRetryTime,
    final int? retryDelay,
    final String? failureReason,
    final int? lastFailureStatusCode,
    final List<String>? retryableErrorTypes,
    final bool? retryOnSpecificErrors,
  }) => NetworkRequest(
    id: id ?? this.id,
    method: method ?? this.method,
    url: url ?? this.url,
    headers: headers ?? this.headers,
    body: body ?? this.body,
    createdAt: createdAt ?? this.createdAt,
    retryCount: retryCount ?? this.retryCount,
    maxRetries: maxRetries ?? this.maxRetries,
    priority: priority ?? this.priority,
    metadata: metadata ?? this.metadata,
    lastRetryTime: lastRetryTime ?? this.lastRetryTime,
    retryDelay: retryDelay ?? this.retryDelay,
    failureReason: failureReason ?? this.failureReason,
    lastFailureStatusCode: lastFailureStatusCode ?? this.lastFailureStatusCode,
    retryableErrorTypes: retryableErrorTypes ?? this.retryableErrorTypes,
    retryOnSpecificErrors: retryOnSpecificErrors ?? this.retryOnSpecificErrors,
  );

  /// Returns true if this request can be retried
  bool get canRetry => retryCount < maxRetries;

  /// Returns true if this request should be retried based on error type
  bool shouldRetryOnError(final String errorType) {
    if (!retryOnSpecificErrors) {
      return true;
    }
    return retryableErrorTypes.contains(errorType);
  }

  /// Creates a new request with incremented retry count and updated retry info
  NetworkRequest withIncrementedRetry({
    final String? failureReason,
    final int? statusCode,
    final int? retryDelay,
  }) => copyWith(
    retryCount: retryCount + 1,
    lastRetryTime: DateTime.now(),
    failureReason: failureReason,
    lastFailureStatusCode: statusCode,
    retryDelay: retryDelay,
  );

  /// Creates a new request with updated failure information
  NetworkRequest withFailureInfo({
    final String? failureReason,
    final int? statusCode,
  }) =>
      copyWith(failureReason: failureReason, lastFailureStatusCode: statusCode);

  /// Converts this request to a JSON map
  Map<String, dynamic> toJson() => {
    'id': id,
    'method': method,
    'url': url,
    'headers': headers,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'retryCount': retryCount,
    'maxRetries': maxRetries,
    'priority': priority,
    'metadata': metadata,
    'lastRetryTime': lastRetryTime?.toIso8601String(),
    'retryDelay': retryDelay,
    'failureReason': failureReason,
    'lastFailureStatusCode': lastFailureStatusCode,
    'retryableErrorTypes': retryableErrorTypes,
    'retryOnSpecificErrors': retryOnSpecificErrors,
  };

  /// Converts this request to a JSON string
  String toJsonString() => jsonEncode(toJson());

  @override
  String toString() =>
      'NetworkRequest{id: $id, method: $method, url: $url, '
      'retryCount: $retryCount, failureReason: $failureReason}';

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is NetworkRequest &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
