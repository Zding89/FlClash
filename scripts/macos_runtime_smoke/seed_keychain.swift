import Foundation
import Security

let environment = ProcessInfo.processInfo.environment
guard environment["GITHUB_ACTIONS"] == "true", environment["RUNNER_OS"] == "macOS",
      CommandLine.arguments.count == 3 else { exit(64) }
let mode = CommandLine.arguments[1]
let executable = CommandLine.arguments[2]
guard let workspace = environment["GITHUB_WORKSPACE"],
      executable.hasPrefix(workspace + "/build/macos/Build/Products/Release/FlClash Usage.app/Contents/MacOS/") else { exit(64) }
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "com.zding.flclash.usage.control.credentials",
    kSecAttrAccount as String: "password",
    kSecAttrSynchronizable as String: false
]
if mode == "remove" {
    let result = SecItemDelete(query as CFDictionary)
    guard result == errSecSuccess || result == errSecItemNotFound else { exit(1) }
    exit(0)
}
guard mode == "seed", SecItemCopyMatching(query as CFDictionary, nil) == errSecItemNotFound else { exit(65) }
let data = FileHandle.standardInput.readDataToEndOfFile()
guard let secret = String(data: data, encoding: .utf8), secret.count >= 12, secret.count <= 128 else { exit(64) }
var trusted: SecTrustedApplication?
guard SecTrustedApplicationCreateFromPath(executable, &trusted) == errSecSuccess, let trusted else { exit(1) }
var access: SecAccess?
guard SecAccessCreate("FlClash CI fixture" as CFString, [trusted] as CFArray, &access) == errSecSuccess, let access else { exit(1) }
var item = query
item[kSecValueData as String] = data
item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
item[kSecAttrAccess as String] = access
guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { exit(1) }
