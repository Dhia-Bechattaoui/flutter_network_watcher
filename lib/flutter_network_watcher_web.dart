// ignore_for_file: avoid_web_libraries_in_flutter

import 'package:flutter_web_plugins/flutter_web_plugins.dart';

export 'src/platform/network_watcher_web.dart';
export 'src/models/network_request.dart';
export 'src/models/network_watcher_config.dart';
export 'src/models/connectivity_state.dart';
export 'src/network_watcher.dart';

/// A web implementation of the FlutterNetworkWatcherPlugin plugin.
class FlutterNetworkWatcherPlugin {
  /// Constructor for FlutterNetworkWatcherPlugin
  FlutterNetworkWatcherPlugin();

  /// Registers the plugin with the Flutter web platform
  static void registerWith(Registrar registrar) {
    // This is a Dart-only plugin, no platform-specific implementation needed
    // All functionality is handled by the connectivity_plus plugin and our platform abstraction
  }
}
