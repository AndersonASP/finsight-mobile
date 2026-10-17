import AppIntents
import Foundation

/// "Registrar gasto" — logs a purchase without opening the app. Built for the
/// Shortcuts *Transaction* automation (Apple Pay): Valor ← Amount,
/// Estabelecimento ← Merchant, Cartão ← Card or Pass.
///
/// When it can't log by itself (offline, Wallet card not linked, logged
/// out), it saves the purchase and asks to continue in the app, which opens
/// the form already filled in.
@available(iOS 17.0, *)
struct RegistrarGastoIntent: AppIntent, ForegroundContinuableIntent {
  static let title: LocalizedStringResource = "Registrar gasto"
  static let description = IntentDescription(
    "Lança uma compra no FinSight sem abrir o app. Use com a automação \"Transação\" do Apple Pay.",
    categoryName: "Lançamentos"
  )
  static let openAppWhenRun = false

  @available(iOS 26.0, *)
  static var supportedModes: IntentModes { [.background, .foreground(.dynamic)] }

  @Parameter(title: "Valor", description: "Valor da compra.")
  var valor: Double

  @Parameter(title: "Estabelecimento", description: "Onde a compra foi feita.")
  var estabelecimento: String

  @Parameter(title: "Cartão", description: "Nome do cartão na Carteira (opcional).")
  var cartao: String?

  static var parameterSummary: some ParameterSummary {
    Summary("Registrar \(\.$valor) em \(\.$estabelecimento)") {
      \.$cartao
    }
  }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    let entry = PendingQuickEntry(
      amount: String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), valor),
      merchant: estabelecimento.trimmingCharacters(in: .whitespacesAndNewlines),
      cardName: cartao?.trimmingCharacters(in: .whitespacesAndNewlines),
      date: Self.localDate()
    )

    do {
      let result = try await FinSightAPI.createQuickEntry(entry)
      let tag = result.categoryName.map { " · \($0)" } ?? ""
      return .result(
        dialog: "\(Self.brl(entry.amount)) em \(result.description) lançado no \(result.paymentName)\(tag)."
      )
    } catch {
      entry.save()
      throw continueInAppError(Self.reason(for: error))
    }
  }

  /// Hands over to the app (which opens the pre-filled form) — via the iOS 26
  /// API when available, else the iOS 17 `ForegroundContinuableIntent` one.
  private func continueInAppError(_ reason: String) -> Error {
    let dialog = IntentDialog("\(reason) Abrir o FinSight para concluir o lançamento?")
    if #available(iOS 26.0, *) {
      return needsToContinueInForegroundError(dialog, alwaysConfirm: true)
    }
    return needsToContinueInForegroundError(dialog, continuation: nil)
  }

  private static func reason(for error: Error) -> String {
    switch error as? FinSightAPIError {
    case .offline: return "Sem conexão com o FinSight."
    case .notLoggedIn: return "Você precisa entrar no FinSight."
    case .server(_, "unmapped_card", let message?): return message
    default: return "O FinSight não conseguiu lançar a compra."
    }
  }

  /// Today on the device's calendar — the server's UTC "today" can already
  /// be tomorrow late in the evening in Brazil.
  private static func localDate() -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: Date())
  }

  private static func brl(_ amount: String) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.locale = Locale(identifier: "pt_BR")
    return formatter.string(from: NSDecimalNumber(string: amount)) ?? "R$ \(amount)"
  }
}

@available(iOS 17.0, *)
struct FinSightShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: RegistrarGastoIntent(),
      phrases: [
        "Registrar gasto no \(.applicationName)",
        "Lançar gasto no \(.applicationName)",
      ],
      shortTitle: "Registrar gasto",
      systemImageName: "creditcard"
    )
  }
}
