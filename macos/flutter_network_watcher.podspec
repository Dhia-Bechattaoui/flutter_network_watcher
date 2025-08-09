#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_network_watcher.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_network_watcher'
  s.version          = '0.0.1'
  s.summary          = 'Real-time network connectivity monitoring with offline queue management for Flutter applications.'
  s.description      = <<-DESC
Real-time network connectivity monitoring with offline queue management for Flutter applications. Seamless state tracking and automatic request queuing.
                       DESC
  s.homepage         = 'https://github.com/Dhia-Bechattaoui/flutter_network_watcher'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Dhia Bechattaoui' => 'dhia@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.14'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
