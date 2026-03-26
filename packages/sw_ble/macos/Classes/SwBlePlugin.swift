// SwBlePlugin.swift  — macOS 平台實作
//
// 與 iOS 版本邏輯完全相同，主要差異有二：
//   1. import FlutterMacOS  （iOS 用 import Flutter + UIKit）
//   2. registrar.messenger  （macOS 是 property；iOS 是 messenger() method）
//
// ObjC++ 核心（SWBleManager / sw_profile）透過 podspec 直接引用
// ios/Classes/ 下的原始碼，不另行複製，避免維護兩份。

import FlutterMacOS

public class SwBlePlugin: NSObject, FlutterPlugin {

    // ── Channel 名稱需與 Dart 層 sw_ble.dart 完全一致 ─────────────────────
    private static let methodChannelName = "sw_ble/methods"
    private static let eventChannelName  = "sw_ble/nearby_peers"

    // ── Flutter Plugin 入口 ───────────────────────────────────────────────
    public static func register(with registrar: FlutterPluginRegistrar) {
        // macOS: registrar.messenger 是 property（無括號）
        // iOS:   registrar.messenger() 是 method（有括號）
        let methodChannel = FlutterMethodChannel(
            name: methodChannelName,
            binaryMessenger: registrar.messenger
        )
        let eventChannel = FlutterEventChannel(
            name: eventChannelName,
            binaryMessenger: registrar.messenger
        )
        let instance = SwBlePlugin()
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
    }

    // ── 成員變數 ──────────────────────────────────────────────────────────
    /// ObjC++ BLE 核心（advertise + scan + 接觸追蹤）
    private let bleManager = SWBleManager()
    /// EventChannel 的 sink，用來把 BLE 事件推給 Dart
    private var eventSink: FlutterEventSink?

    override init() {
        super.init()

        // 把所有接觸事件（peer_found / peer_update / peer_lost）轉送到 Dart
        bleManager.onContactEvent = { [weak self] event in
            self?.eventSink?(event)
        }

        // 把 BLE 狀態變化（ready / poweredOff / unauthorized…）轉送到 Dart
        bleManager.onStateChanged = { [weak self] state in
            self?.eventSink?(["_state": state as Any])
        }
    }

    // ── MethodChannel 處理 ────────────────────────────────────────────────
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {

        case "setProfile":
            // 參數：{ name: String, mbtiIndex: Int (0–15) }
            guard
                let args      = call.arguments as? [String: Any],
                let name      = args["name"] as? String,
                let mbtiIndex = args["mbtiIndex"] as? Int,
                mbtiIndex >= 0, mbtiIndex < 16
            else {
                result(FlutterError(
                    code: "BAD_ARGS",
                    message: "setProfile requires name (String) and mbtiIndex (0–15)",
                    details: nil
                ))
                return
            }
            bleManager.setProfileWithName(name, mbtiIndex: UInt8(mbtiIndex))
            result(nil)

        case "startBle":
            // 啟動 CBCentralManager（掃描）+ CBPeripheralManager（廣播）
            bleManager.startBle()
            result(nil)

        case "stopBle":
            // 停止掃描與廣播，並把所有進行中的接觸以 peer_lost 事件結束
            bleManager.stopBle()
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

// ── EventChannel 串流處理 ──────────────────────────────────────────────────
extension SwBlePlugin: FlutterStreamHandler {
    public func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        // Dart 側呼叫 SwBle.contactEvents.listen() 時觸發
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        // Dart 側取消訂閱時觸發
        self.eventSink = nil
        return nil
    }
}
