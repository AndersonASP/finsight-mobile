import Foundation

enum FinSightAPIError: Error {
  /// No session mirrored from the app yet, or the refresh token was revoked.
  case notLoggedIn
  /// The server couldn't be reached.
  case offline
  /// The server answered with an error; `message` is its user-facing text.
  case server(status: Int, code: String?, message: String?)
}

struct QuickEntryResult: Decodable {
  let kind: String
  let description: String
  let amount: String
  let categoryName: String?
  let paymentName: String
}

/// Minimal API client for the App Intents: bearer auth with one silent
/// refresh on 401, using the session mirrored in `NativeSession`.
enum FinSightAPI {
  static func createQuickEntry(_ entry: PendingQuickEntry) async throws -> QuickEntryResult {
    var body: [String: Any] = ["amount": entry.amount, "merchant": entry.merchant, "date": entry.date]
    if let cardName = entry.cardName, !cardName.isEmpty { body["cardName"] = cardName }
    let data = try await send("POST", "/quick-entries", body: body)
    return try JSONDecoder().decode(QuickEntryResult.self, from: data)
  }

  private static func send(_ method: String, _ path: String, body: [String: Any]?, retried: Bool = false) async throws -> Data {
    guard let baseUrl = NativeSession.apiBaseUrl, NativeSession.refreshToken != nil else {
      throw FinSightAPIError.notLoggedIn
    }
    if NativeSession.accessToken == nil {
      try await refreshAccessToken(baseUrl)
    }

    var request = URLRequest(url: baseUrl.appendingPathComponent(path), timeoutInterval: 20)
    request.httpMethod = method
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(NativeSession.accessToken ?? "")", forHTTPHeaderField: "Authorization")
    if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body) }

    let (data, status) = try await perform(request)
    if status == 401 && !retried {
      try await refreshAccessToken(baseUrl)
      return try await send(method, path, body: body, retried: true)
    }
    guard (200..<300).contains(status) else { throw serverError(status, data) }
    return data
  }

  private static func refreshAccessToken(_ baseUrl: URL) async throws {
    guard let refreshToken = NativeSession.refreshToken else { throw FinSightAPIError.notLoggedIn }
    var request = URLRequest(url: baseUrl.appendingPathComponent("/auth/refresh"), timeoutInterval: 20)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: ["refreshToken": refreshToken])

    let (data, status) = try await perform(request)
    if status == 401 {
      NativeSession.clear()
      throw FinSightAPIError.notLoggedIn
    }
    guard (200..<300).contains(status),
          let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let accessToken = json["accessToken"] as? String
    else { throw serverError(status, data) }
    NativeSession.accessToken = accessToken
  }

  private static func perform(_ request: URLRequest) async throws -> (Data, Int) {
    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    } catch {
      throw FinSightAPIError.offline
    }
  }

  /// The API's error body is `{ "error": { "code", "message" } }`.
  private static func serverError(_ status: Int, _ data: Data) -> FinSightAPIError {
    let error = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? [String: Any]
    return .server(status: status, code: error?["code"] as? String, message: error?["message"] as? String)
  }
}
