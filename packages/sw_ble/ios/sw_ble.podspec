Pod::Spec.new do |s|
  s.name             = 'sw_ble'
  s.version          = '0.0.1'
  s.summary          = 'BLE advertise/scan plugin for the SW MBTI POC.'
  s.homepage         = 'https://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'SW' => 'dev@example.com' }
  s.source           = { :path => '.' }

  # Include all Swift, Obj-C++, C++ and header files under Classes/.
  s.source_files = 'Classes/**/*.{h,cpp,mm,swift}'

  # Only the Obj-C interface is public so CocoaPods puts it in the
  # module umbrella header. C++ headers must NOT be public — they would
  # be #included in the umbrella and fail ObjC compilation.
  s.public_header_files = 'Classes/SWBleManager.h'

  s.dependency 'Flutter'
  s.platform = :ios, '14.0'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE'               => 'YES',
    'CLANG_CXX_LANGUAGE_STANDARD'  => 'c++17',
    # Bridging headers are unsupported for framework targets.
    # Swift sees SWBleManager via the auto-generated module umbrella header.
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
  }

  s.swift_version = '5.0'
  s.frameworks    = 'CoreBluetooth'
end
