import FlutterMacOS
import Foundation

/// A macOS implementation of the FlutterNetworkWatcherPlugin
public class FlutterNetworkWatcherPlugin: NSObject, FlutterPlugin {
    
    /// Registers the plugin with the Flutter engine
    public static func register(with registrar: FlutterPluginRegistrar) {
        // This is a Dart-only plugin, no platform-specific implementation needed
        // All functionality is handled by the connectivity_plus plugin and our platform abstraction
    }
    
    /// Handles method calls from Flutter
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // This plugin doesn't expose any platform-specific methods
        result(FlutterMethodNotImplemented)
    }
}
