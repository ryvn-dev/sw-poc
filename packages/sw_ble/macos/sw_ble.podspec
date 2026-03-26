Pod::Spec.new do |s|
  s.name             = 'sw_ble'
  s.version          = '0.0.1'
  s.summary          = 'BLE advertise/scan plugin for the SW MBTI POC (macOS).'
  s.homepage         = 'https://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'SW' => 'dev@example.com' }
  s.source           = { :path => '.' }

  # ── 原始碼 ──────────────────────────────────────────────────────────────
  # macOS Swift 入口點在本目錄的 Classes/ 下。
  # C++/ObjC++ 核心（sw_profile + SWBleManager）與 iOS 共用，
  # 直接引用 ios/Classes/ 的原始碼，避免重複維護。
  # 所有原始碼都放在 Classes/ 下（C++/ObjC++ 以 symlink 指向 ios/Classes/ 的實作）。
  # CocoaPods 不支援 source_files 路徑超出 pod 根目錄（../），所以用 symlink 讓路徑留在內部。
  s.source_files = 'Classes/**/*.{h,cpp,mm,swift}'

  # public_header_files 必須在 pod 根目錄內，CocoaPods 才會把它加入 umbrella header，
  # Swift 才能透過自動生成的 module umbrella header 看見 SWBleManager。
  # Classes/SWBleManager.h 是 ios/Classes/SWBleManager.h 的 symlink。
  s.public_header_files = 'Classes/SWBleManager.h'

  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.15'

  s.pod_target_xcconfig = {
    # 讓 Swift 能透過自動生成的 umbrella header 看見 SWBleManager
    'DEFINES_MODULE'              => 'YES',
    # 啟用 C++17（sw_profile.cpp 使用 std::vector / enum class）
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    # 告訴編譯器去哪裡找共用的 header 檔
    'HEADER_SEARCH_PATHS'         => '$(PODS_TARGET_SRCROOT)/../ios/Classes',
  }

  s.swift_version = '5.0'
  # CoreBluetooth 在 macOS 10.15+ 完整支援 advertise + scan
  s.frameworks = 'CoreBluetooth'
end
