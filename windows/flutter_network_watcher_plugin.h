#ifndef FLUTTER_PLUGIN_FLUTTER_NETWORK_WATCHER_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_NETWORK_WATCHER_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace flutter_network_watcher {

class FlutterNetworkWatcherPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  FlutterNetworkWatcherPlugin();

  virtual ~FlutterNetworkWatcherPlugin();

  // Disallow copy and assign.
  FlutterNetworkWatcherPlugin(const FlutterNetworkWatcherPlugin&) = delete;
  FlutterNetworkWatcherPlugin& operator=(const FlutterNetworkWatcherPlugin&) = delete;

 private:
  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace flutter_network_watcher

#endif  // FLUTTER_PLUGIN_FLUTTER_NETWORK_WATCHER_PLUGIN_H_
