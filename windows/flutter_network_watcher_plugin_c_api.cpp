#include "include/flutter_network_watcher/flutter_network_watcher_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "flutter_network_watcher_plugin.h"

void FlutterNetworkWatcherPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flutter_network_watcher::FlutterNetworkWatcherPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
