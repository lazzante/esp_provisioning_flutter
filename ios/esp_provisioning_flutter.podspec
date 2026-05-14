#
# Pod spec for the esp_provisioning_flutter Flutter plugin.
# Run `pod lib lint esp_provisioning_flutter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'esp_provisioning_flutter'
  s.version          = '0.0.1'
  s.summary          = 'Flutter plugin for provisioning ESP32 devices over BLE and SoftAP.'
  s.description      = <<-DESC
Flutter plugin for provisioning Espressif ESP32 devices over BLE and SoftAP.
Wraps the official ESPProvision iOS SDK and the esp-idf-provisioning-android
library through a strictly-typed, sealed Dart API.
                       DESC
  s.homepage         = 'https://github.com/lazzante/esp_provisioning_flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Mande Dijital / RainyBit' => 'info@mandedijital.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.platform         = :ios, '13.0'
  s.swift_version    = '5.0'

  s.dependency 'Flutter'
  # Espressif's official iOS provisioning SDK. Pinned to the latest 3.x line —
  # 3.1+ ships the SRP6a security2 handshake required for production-grade
  # firmware. Do NOT bump to a `next` / beta tag.
  s.dependency 'ESPProvision', '~> 3.1'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }

  s.resource_bundles = {
    'esp_provisioning_flutter_privacy' => ['Resources/PrivacyInfo.xcprivacy']
  }
end
