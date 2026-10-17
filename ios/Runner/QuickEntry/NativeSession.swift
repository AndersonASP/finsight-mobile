import Foundation
import Security

/// The session the App Intents use to call the API, mirrored from Flutter
/// (which keeps its own copy encrypted in a format Swift can't read).
///
/// Tokens live in the keychain readable *after first unlock*, so an Apple Pay
/// automation still works while the iPhone is locked.
enum NativeSession {
  private static let service = "dev.andalsp.finsight.native"
  private static let accessTokenAccount = "accessToken"
  private static let refreshTokenAccount = "refreshToken"
  private static let apiBaseUrlKey = "native.apiBaseUrl"

  static var apiBaseUrl: URL? {
    get { UserDefaults.standard.string(forKey: apiBaseUrlKey).flatMap(URL.init(string:)) }
    set { UserDefaults.standard.set(newValue?.absoluteString, forKey: apiBaseUrlKey) }
  }

  static var accessToken: String? {
    get { read(accessTokenAccount) }
    set { write(accessTokenAccount, newValue) }
  }

  static var refreshToken: String? {
    get { read(refreshTokenAccount) }
    set { write(refreshTokenAccount, newValue) }
  }

  static func clear() {
    accessToken = nil
    refreshToken = nil
  }

  private static func baseQuery(_ account: String) -> [CFString: Any] {
    [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: account,
    ]
  }

  private static func read(_ account: String) -> String? {
    var query = baseQuery(account)
    query[kSecReturnData] = true
    query[kSecMatchLimit] = kSecMatchLimitOne
    var result: AnyObject?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
          let data = result as? Data
    else { return nil }
    return String(data: data, encoding: .utf8)
  }

  private static func write(_ account: String, _ value: String?) {
    SecItemDelete(baseQuery(account) as CFDictionary)
    guard let value, let data = value.data(using: .utf8) else { return }
    var query = baseQuery(account)
    query[kSecValueData] = data
    query[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    SecItemAdd(query as CFDictionary, nil)
  }
}

/// A purchase an automation couldn't log by itself, left for the app to
/// open pre-filled (see `openPendingQuickEntry` on the Flutter side).
struct PendingQuickEntry: Codable {
  let amount: String
  let merchant: String
  let cardName: String?
  let date: String

  private static let key = "native.pendingQuickEntry"

  func save() {
    UserDefaults.standard.set(try? JSONEncoder().encode(self), forKey: Self.key)
  }

  /// Returns and removes the pending entry, if any.
  static func take() -> PendingQuickEntry? {
    defer { UserDefaults.standard.removeObject(forKey: key) }
    guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
    return try? JSONDecoder().decode(PendingQuickEntry.self, from: data)
  }

  var asDictionary: [String: Any] {
    var dict: [String: Any] = ["amount": amount, "merchant": merchant, "date": date]
    if let cardName { dict["cardName"] = cardName }
    return dict
  }
}
