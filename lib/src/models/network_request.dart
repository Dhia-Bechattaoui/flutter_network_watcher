import 'dart:convert';

/// Represents a network request that can be queued for offline execution
class NetworkRequest {
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

  /// Creates a new network request
  const NetworkRequest({
    required this.id,
    required this.method,
    required this.url,
    this.headers = const {},
    this.body,
    required this.createdAt,
    this.retryCount = 0,
    this.maxRetries = 3,
    this.priority = 0,
    this.metadata,
  });

  /// Creates a copy of this request with updated values
  NetworkRequest copyWith({
    String? id,
    String? method,
    String? url,
    Map<String, String>? headers,
    String? body,
    DateTime? createdAt,
    int? retryCount,
    int? maxRetries,
    int? priority,
    Map<String, dynamic>? metadata,
  }) {
    return NetworkRequest(
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
    );
  }

  /// Returns true if this request can be retried
  bool get canRetry => retryCount < maxRetries;

  /// Creates a new request with incremented retry count
  NetworkRequest withIncrementedRetry() {
    return copyWith(retryCount: retryCount + 1);
  }

  /// Converts this request to a JSON map
  Map<String, dynamic> toJson() {
    return {
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
    };
  }

  /// Creates a NetworkRequest from a JSON map
  factory NetworkRequest.fromJson(Map<String, dynamic> json) {
    return NetworkRequest(
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
    );
  }

  /// Converts this request to a JSON string
  String toJsonString() => jsonEncode(toJson());

  /// Creates a NetworkRequest from a JSON string
  factory NetworkRequest.fromJsonString(String jsonString) {
    return NetworkRequest.fromJson(
        jsonDecode(jsonString) as Map<String, dynamic>);
  }

  @override
  String toString() {
    return 'NetworkRequest{id: $id, method: $method, url: $url, retryCount: $retryCount}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NetworkRequest &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
