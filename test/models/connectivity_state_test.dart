import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_network_watcher/src/models/connectivity_state.dart';

void main() {
  group('ConnectivityState', () {
    test('isConnected returns true for connected states', () {
      expect(ConnectivityState.wifi.isConnected, isTrue);
      expect(ConnectivityState.mobile.isConnected, isTrue);
      expect(ConnectivityState.ethernet.isConnected, isTrue);
      expect(ConnectivityState.unknown.isConnected, isTrue);
    });

    test('isConnected returns false for none state', () {
      expect(ConnectivityState.none.isConnected, isFalse);
    });

    test('isOffline returns true only for none state', () {
      expect(ConnectivityState.none.isOffline, isTrue);
      expect(ConnectivityState.wifi.isOffline, isFalse);
      expect(ConnectivityState.mobile.isOffline, isFalse);
      expect(ConnectivityState.ethernet.isOffline, isFalse);
      expect(ConnectivityState.unknown.isOffline, isFalse);
    });

    test('description returns correct strings', () {
      expect(ConnectivityState.wifi.description, equals('Connected via WiFi'));
      expect(ConnectivityState.mobile.description,
          equals('Connected via mobile data'));
      expect(ConnectivityState.ethernet.description,
          equals('Connected via ethernet'));
      expect(
          ConnectivityState.none.description, equals('No internet connection'));
      expect(ConnectivityState.unknown.description,
          equals('Unknown connection state'));
    });
  });
}
