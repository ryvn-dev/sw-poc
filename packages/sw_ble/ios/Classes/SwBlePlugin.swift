import Flutter
import UIKit

public class SwBlePlugin: NSObject, FlutterPlugin {

    private static let methodChannelName = "sw_ble/methods"
    private static let eventChannelName  = "sw_ble/nearby_peers"

    public static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(
            name: methodChannelName,
            binaryMessenger: registrar.messenger()
        )
        let eventChannel = FlutterEventChannel(
            name: eventChannelName,
            binaryMessenger: registrar.messenger()
        )
        let instance = SwBlePlugin()
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
    }

    private let bleManager = SWBleManager()
    private var eventSink: FlutterEventSink?

    override init() {
        super.init()

        // Forward all contact events (peer_found / peer_update / peer_lost) to Dart.
        bleManager.onContactEvent = { [weak self] event in
            self?.eventSink?(event)
        }

        // Forward BLE state changes as a special dict.
        bleManager.onStateChanged = { [weak self] state in
            self?.eventSink?(["_state": state as Any])
        }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {

        case "setProfile":
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
            bleManager.startBle()
            result(nil)

        case "stopBle":
            bleManager.stopBle()
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

extension SwBlePlugin: FlutterStreamHandler {
    public func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
