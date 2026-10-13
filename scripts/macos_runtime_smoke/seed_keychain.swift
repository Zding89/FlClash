import Foundation
import Security

let environment = ProcessInfo.processInfo.environment
guard environment["GITHUB_ACTIONS"] == "true", environment["RUNNER_OS"] == "macOS",
      environment["RUNNER_ENVIRONMENT"] == "github-hosted",
      CommandLine.arguments.count == 4 else { exit(64) }
let mode = CommandLine.arguments[1]
let executable = CommandLine.arguments[2]
let keychainPath = CommandLine.arguments[3]
guard let workspace = environment["GITHUB_WORKSPACE"],
      executable.hasPrefix(workspace + "/build/macos/Build/Products/Release/FlClash Usage.app/Contents/MacOS/"),
      keychainPath.hasPrefix("/private/tmp/flclash-macos-smoke-"),
      keychainPath.hasSuffix("/fixture.keychain-db") else { exit(64) }
guard SecKeychainSetUserInteractionAllowed(false) == errSecSuccess else { exit(1) }
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "com.zding.flclash.usage.control.credentials",
    kSecAttrAccount as String: "password",
    kSecAttrSynchronizable as String: false
]
if mode == "remove" {
    var keychain: SecKeychain?
    guard SecKeychainOpen(keychainPath, &keychain) == errSecSuccess, let keychain,
          SecKeychainDelete(keychain) == errSecSuccess else { exit(1) }
    exit(0)
}
guard mode == "seed", SecItemCopyMatching(query as CFDictionary, nil) == errSecItemNotFound else { exit(65) }
let input = FileHandle.standardInput.readDataToEndOfFile()
guard let credentials = try? JSONSerialization.jsonObject(with: input) as? [String: String],
      let secret = credentials["password"], secret.count >= 12, secret.count <= 128,
      let keychainPassword = credentials["keychainPassword"], keychainPassword.count >= 32,
      !FileManager.default.fileExists(atPath: keychainPath) else { exit(64) }
let keychainData = Data(keychainPassword.utf8)
var keychain: SecKeychain?
let createStatus = keychainData.withUnsafeBytes {
    SecKeychainCreate(keychainPath, UInt32(keychainData.count), $0.baseAddress, false, nil, &keychain)
}
guard createStatus == errSecSuccess, let keychain else { exit(1) }
let unlockStatus = keychainData.withUnsafeBytes {
    SecKeychainUnlock(keychain, UInt32(keychainData.count), $0.baseAddress, true)
}
guard unlockStatus == errSecSuccess else { exit(1) }
var trusted: SecTrustedApplication?
guard SecTrustedApplicationCreateFromPath(executable, &trusted) == errSecSuccess, let trusted else { exit(1) }
var access: SecAccess?
guard SecAccessCreate("FlClash CI fixture" as CFString, [trusted] as CFArray, &access) == errSecSuccess, let access else { exit(1) }
var item = query
item[kSecUseKeychain as String] = keychain
item[kSecValueData as String] = Data(secret.utf8)
item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
item[kSecAttrAccess as String] = access
guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { exit(1) }
