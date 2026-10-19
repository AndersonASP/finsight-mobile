import Flutter
import Foundation

/// `dev.andalsp.finsight/native` — see `NativeBridge` on the Flutter side.
enum NativeChannel {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "dev.andalsp.finsight/native",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "setSession":
        NativeSession.migrateToSharedGroup()
        let args = call.arguments as? [String: Any] ?? [:]
        if let baseUrl = args["apiBaseUrl"] as? String {
          NativeSession.apiBaseUrl = URL(string: baseUrl)
        }
        if let accessToken = args["accessToken"] as? String {
          NativeSession.accessToken = accessToken
        }
        if let refreshToken = args["refreshToken"] as? String {
          NativeSession.refreshToken = refreshToken
        }
        result(nil)
      case "clearSession":
        NativeSession.clear()
        result(nil)
      case "takePendingQuickEntry":
        result(PendingQuickEntry.take()?.asDictionary)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
