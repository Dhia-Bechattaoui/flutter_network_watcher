/// Represents the current network connectivity state
enum ConnectivityState {
  /// Device is connected to the internet via WiFi
  wifi,

  /// Device is connected to the internet via mobile data
  mobile,

  /// Device is connected to ethernet
  ethernet,

  /// Device has no internet connection
  none,

  /// Device connectivity state is unknown
  unknown;

  /// Returns true if the device has an active internet connection
  bool get isConnected => this != ConnectivityState.none;

  /// Returns true if the device is offline
  bool get isOffline => this == ConnectivityState.none;

  /// Returns a human-readable description of the connectivity state
  String get description {
    switch (this) {
      case ConnectivityState.wifi:
        return 'Connected via WiFi';
      case ConnectivityState.mobile:
        return 'Connected via mobile data';
      case ConnectivityState.ethernet:
        return 'Connected via ethernet';
      case ConnectivityState.none:
        return 'No internet connection';
      case ConnectivityState.unknown:
        return 'Unknown connection state';
    }
  }
}
