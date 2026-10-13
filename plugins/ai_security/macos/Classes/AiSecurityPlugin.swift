import Cocoa
import FlutterMacOS
import Security

public class AiSecurityPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flclash/ai_security", binaryMessenger: registrar.messenger)
        registrar.addMethodCallDelegate(AiSecurityPlugin(), channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let id = arguments["id"] as? String,
              id.range(of: "\\A[A-Za-z0-9_-]{1,96}\\z", options: .regularExpression) != nil,
              let bundleId = Bundle.main.bundleIdentifier else {
            result(FlutterError(code: "invalidCredentialId", message: nil, details: nil))
            return
        }
        let namespace = arguments["namespace"] as? String ?? "ai"
        guard namespace == "ai" || namespace == "control" else {
            result(FlutterError(code: "invalidNamespace", message: nil, details: nil))
            return
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: bundleId + "." + namespace + ".credentials",
            kSecAttrAccount as String: id,
            kSecAttrSynchronizable as String: false
        ]
        switch call.method {
        case "get":
            var search = query
            search[kSecReturnData as String] = true
            search[kSecMatchLimit as String] = kSecMatchLimitOne
            var value: CFTypeRef?
            let status = SecItemCopyMatching(search as CFDictionary, &value)
            if status == errSecItemNotFound {
                result(nil)
            } else if status == errSecSuccess, let data = value as? Data,
                      let secret = String(data: data, encoding: .utf8) {
                result(secret)
            } else {
                fail(status, result)
            }
        case "set":
            guard let secret = arguments["secret"] as? String,
                  !secret.isEmpty, secret.utf8.count <= 65536,
                  let data = secret.data(using: .utf8) else {
                result(FlutterError(code: "invalidSecret", message: nil, details: nil))
                return
            }
            let attributes: [String: Any] = [kSecValueData as String: data]
            var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            if status == errSecItemNotFound {
                var item = query
                item[kSecValueData as String] = data
                item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
                status = SecItemAdd(item as CFDictionary, nil)
            }
            if status == errSecSuccess { result(nil) } else { fail(status, result) }
        case "delete":
            let status = SecItemDelete(query as CFDictionary)
            if status == errSecSuccess || status == errSecItemNotFound {
                result(nil)
            } else {
                fail(status, result)
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func fail(_ status: OSStatus, _ result: FlutterResult) {
        result(FlutterError(code: "keychainFailure", message: nil, details: ["status": status]))
    }
}
