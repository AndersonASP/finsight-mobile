import SwiftUI
import WidgetKit

// The app writes `/insights/summary` into the shared App Group (see
// lib/core/home_widget/widget_sync.dart) whenever its data changes. The
// widget also fetches it itself on every timeline reload (about every 30
// min, and right after "Registrar gasto"), with the session the app mirrors
// into the App Group keychain (NativeSession), so it stays fresh with the
// app closed. Offline or logged out, it keeps showing the last snapshot.

private let appGroupId = "group.dev.andalsp.finsight"
private let summaryKey = "summary"

struct Summary: Decodable {
  struct Lowest: Decodable {
    let date: String
    let value: String
  }

  struct Bill: Decodable {
    let description: String
    let amount: String
    let dueDate: String
  }

  struct RedSea: Decodable {
    struct Month: Decodable {
      let mes: String
      let menorSaldo: String?
      let precisaAteOMes: String
    }

    let limiteVerde: String
    let horizonteMeses: Int
    let precisaEntrar: String
    let paraSairDoNegativo: String
    let piorDia: Lowest?
    let primeiroMesNoVermelho: String?
    let meses: [Month]
  }

  let asOf: String
  let saldoHoje: String
  let saldoFimDoMes: String?
  let menorSaldo: Lowest?
  let podeGuardar: String
  let proximasContas: [Bill]
  /// Optional: snapshots written before the "mar vermelho" existed lack it.
  let marVermelho: RedSea?

  /// Best effort: on any failure the last snapshot stays.
  static func refreshFromAPI() async {
    guard NativeSession.refreshToken != nil,
          let json = try? await FinSightAPI.fetchSummaryJSON(),
          let data = json.data(using: .utf8),
          (try? JSONDecoder().decode(Summary.self, from: data)) != nil
    else { return }
    UserDefaults(suiteName: appGroupId)?.set(json, forKey: summaryKey)
  }

  static func load() -> Summary? {
    guard let json = UserDefaults(suiteName: appGroupId)?.string(forKey: summaryKey),
          let data = json.data(using: .utf8)
    else { return nil }
    return try? JSONDecoder().decode(Summary.self, from: data)
  }

  static let sample = Summary(
    asOf: ISO8601DateFormatter().string(from: Date()),
    saldoHoje: "3240.00",
    saldoFimDoMes: "1180.00",
    menorSaldo: nil,
    podeGuardar: "640.00",
    proximasContas: [
      Bill(description: "Internet", amount: "120.00", dueDate: "2026-10-20"),
      Bill(description: "Aluguel", amount: "1500.00", dueDate: "2026-10-30"),
    ],
    marVermelho: RedSea(
      limiteVerde: "500.00",
      horizonteMeses: 12,
      precisaEntrar: "2350.00",
      paraSairDoNegativo: "1850.00",
      piorDia: Lowest(date: "2027-02-10", value: "-1850.00"),
      primeiroMesNoVermelho: "2026-11",
      meses: [
        RedSea.Month(mes: "2026-10", menorSaldo: "820.00", precisaAteOMes: "0.00"),
        RedSea.Month(mes: "2026-11", menorSaldo: "-420.00", precisaAteOMes: "920.00"),
        RedSea.Month(mes: "2026-12", menorSaldo: "-980.00", precisaAteOMes: "1480.00"),
        RedSea.Month(mes: "2027-01", menorSaldo: "-1300.00", precisaAteOMes: "1800.00"),
        RedSea.Month(mes: "2027-02", menorSaldo: "-1850.00", precisaAteOMes: "2350.00"),
        RedSea.Month(mes: "2027-03", menorSaldo: "250.00", precisaAteOMes: "2350.00"),
      ]
    )
  )
}

// MARK: - Formatting

private enum Format {
  static let currency: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.locale = Locale(identifier: "pt_BR")
    return f
  }()

  /// Without cents — what fits on the lock screen.
  static let currencyShort: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.locale = Locale(identifier: "pt_BR")
    f.maximumFractionDigits = 0
    return f
  }()

  static func brl(_ value: String, short: Bool = false) -> String {
    let number = NSDecimalNumber(string: value)
    return (short ? currencyShort : currency).string(from: number) ?? "R$ \(value)"
  }

  static func isNegative(_ value: String) -> Bool {
    NSDecimalNumber(string: value).compare(NSDecimalNumber.zero) == .orderedAscending
  }

  /// "hoje", "amanhã" or "dd/MM" for a YYYY-MM-DD date.
  static func day(_ iso: String) -> String {
    let parser = DateFormatter()
    parser.locale = Locale(identifier: "en_US_POSIX")
    parser.dateFormat = "yyyy-MM-dd"
    guard let date = parser.date(from: iso) else { return iso }
    let calendar = Calendar.current
    if calendar.isDateInToday(date) { return "hoje" }
    if calendar.isDateInTomorrow(date) { return "amanhã" }
    let out = DateFormatter()
    out.dateFormat = "dd/MM"
    return out.string(from: date)
  }

  /// "out/26" for "2026-10".
  static func month(_ ym: String) -> String {
    let parser = DateFormatter()
    parser.locale = Locale(identifier: "en_US_POSIX")
    parser.dateFormat = "yyyy-MM"
    guard let date = parser.date(from: ym) else { return ym }
    let out = DateFormatter()
    out.locale = Locale(identifier: "pt_BR")
    out.dateFormat = "MMM/yy"
    return out.string(from: date).replacingOccurrences(of: ".", with: "")
  }

  /// "15/02/27" for a YYYY-MM-DD date.
  static func fullDay(_ iso: String) -> String {
    let parser = DateFormatter()
    parser.locale = Locale(identifier: "en_US_POSIX")
    parser.dateFormat = "yyyy-MM-dd"
    guard let date = parser.date(from: iso) else { return iso }
    let out = DateFormatter()
    out.dateFormat = "dd/MM/yy"
    return out.string(from: date)
  }

  static func isZero(_ value: String) -> Bool {
    NSDecimalNumber(string: value).compare(NSDecimalNumber.zero) != .orderedDescending
  }

  static func updatedAt(_ iso: String) -> String {
    let parser = ISO8601DateFormatter()
    parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    guard let date = parser.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else { return "" }
    let out = DateFormatter()
    out.dateFormat = Calendar.current.isDateInToday(date) ? "HH:mm" : "dd/MM HH:mm"
    return "atualizado \(out.string(from: date))"
  }
}

// MARK: - Timeline

struct SummaryEntry: TimelineEntry {
  let date: Date
  let summary: Summary?
}

struct SummaryProvider: TimelineProvider {
  func placeholder(in context: Context) -> SummaryEntry {
    SummaryEntry(date: Date(), summary: .sample)
  }

  func getSnapshot(in context: Context, completion: @escaping (SummaryEntry) -> Void) {
    completion(SummaryEntry(date: Date(), summary: context.isPreview ? .sample : Summary.load() ?? .sample))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<SummaryEntry>) -> Void) {
    Task {
      await Summary.refreshFromAPI()
      let entry = SummaryEntry(date: Date(), summary: Summary.load())
      // WidgetKit budgets reloads; ~30 min keeps lançamentos made outside
      // the app (Claude, another device) and "hoje/amanhã" up to date.
      completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(30 * 60))))
    }
  }
}

// MARK: - Views

private let saldoGreen = Color(red: 0.18, green: 0.55, blue: 0.34)
private let saldoRed = Color(red: 0.82, green: 0.33, blue: 0.12)
private let saldoYellow = Color(red: 0.80, green: 0.62, blue: 0.10)

/// Same tiers as the Saldos table: red below zero, yellow up to the green line.
private func tierColor(_ value: String, green: String) -> Color {
  let v = NSDecimalNumber(string: value)
  if v.compare(NSDecimalNumber.zero) == .orderedAscending { return saldoRed }
  if v.compare(NSDecimalNumber(string: green)) == .orderedAscending { return saldoYellow }
  return saldoGreen
}

private struct EmptyState: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("FinSight").font(.caption).bold()
      Text("Abra o app para carregar seus números.")
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
  }
}

private struct SaldoBlock: View {
  let summary: Summary

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text("Saldo hoje").font(.caption2).foregroundStyle(.secondary)
      Text(Format.brl(summary.saldoHoje))
        .font(.title3)
        .bold()
        .minimumScaleFactor(0.6)
        .lineLimit(1)
        .foregroundStyle(Format.isNegative(summary.saldoHoje) ? saldoRed : .primary)
        .privacySensitive()
      if let end = summary.saldoFimDoMes {
        Text("Fim do mês: \(Format.brl(end, short: true))")
          .font(.caption2)
          .foregroundStyle(Format.isNegative(end) ? saldoRed : .secondary)
          .privacySensitive()
      }
    }
  }
}

/// The "mar vermelho" line: how much has to come in to stay green — or,
/// when the caixa is already green, what can be saved this month.
private struct GreenLine: View {
  let summary: Summary

  var body: some View {
    if let red = summary.marVermelho, !Format.isZero(red.precisaEntrar) {
      VStack(alignment: .leading, spacing: 0) {
        Text("Para ficar no verde").font(.system(size: 10)).foregroundStyle(.secondary)
        Text("falta \(Format.brl(red.precisaEntrar, short: true))")
          .font(.caption)
          .bold()
          .foregroundStyle(saldoRed)
          .minimumScaleFactor(0.7)
          .lineLimit(1)
          .privacySensitive()
      }
    } else if summary.marVermelho != nil {
      VStack(alignment: .leading, spacing: 0) {
        Text("Caixa no verde ✓").font(.caption).bold().foregroundStyle(saldoGreen)
        if !Format.isZero(summary.podeGuardar) {
          Text("dá p/ guardar \(Format.brl(summary.podeGuardar, short: true))")
            .font(.system(size: 10))
            .foregroundStyle(saldoGreen)
            .privacySensitive()
        }
      }
    }
  }
}

private struct UpdatedAt: View {
  let summary: Summary

  var body: some View {
    Text(Format.updatedAt(summary.asOf)).font(.system(size: 9)).foregroundStyle(.tertiary)
  }
}

private struct LeftColumn: View {
  let summary: Summary

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      SaldoBlock(summary: summary)
      GreenLine(summary: summary)
      Spacer(minLength: 0)
      UpdatedAt(summary: summary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// Lowest saldo of each coming month, colored like the Saldos table.
private struct MonthsList: View {
  let red: Summary.RedSea
  let count: Int

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text("Menor saldo do mês").font(.caption2).foregroundStyle(.secondary)
      ForEach(Array(red.meses.prefix(count).enumerated()), id: \.offset) { _, month in
        HStack(spacing: 4) {
          Circle()
            .fill(tierColor(month.menorSaldo ?? "0", green: red.limiteVerde))
            .frame(width: 7, height: 7)
          Text(Format.month(month.mes)).font(.caption2)
          Spacer(minLength: 2)
          Text(month.menorSaldo.map { Format.brl($0, short: true) } ?? "—")
            .font(.caption2)
            .foregroundStyle(tierColor(month.menorSaldo ?? "0", green: red.limiteVerde))
            .privacySensitive()
        }
      }
    }
  }
}

private struct BillsList: View {
  let summary: Summary

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Próximas contas").font(.caption2).foregroundStyle(.secondary)
      if summary.proximasContas.isEmpty {
        Text("Nada a pagar nos próximos dias 🎉").font(.caption2)
      }
      ForEach(Array(summary.proximasContas.enumerated()), id: \.offset) { _, bill in
        HStack(spacing: 4) {
          VStack(alignment: .leading, spacing: 0) {
            Text(bill.description).font(.caption).lineLimit(1)
            Text(Format.day(bill.dueDate)).font(.system(size: 10)).foregroundStyle(.secondary)
          }
          Spacer(minLength: 2)
          Text(Format.brl(bill.amount, short: true)).font(.caption).privacySensitive()
        }
      }
    }
  }
}

private struct SmallView: View {
  let summary: Summary

  var body: some View {
    LeftColumn(summary: summary)
  }
}

/// Right side: the coming months while there's a "mar vermelho" to watch;
/// once everything is green, the next bills instead.
private struct MediumView: View {
  let summary: Summary

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      LeftColumn(summary: summary)
      Group {
        if let red = summary.marVermelho, !Format.isZero(red.precisaEntrar) {
          MonthsList(red: red, count: 4)
        } else {
          BillsList(summary: summary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

private struct LargeView: View {
  let summary: Summary

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        SaldoBlock(summary: summary).frame(maxWidth: .infinity, alignment: .leading)
        GreenLine(summary: summary).frame(maxWidth: .infinity, alignment: .leading)
      }
      if let red = summary.marVermelho {
        if let worst = red.piorDia, !Format.isZero(red.precisaEntrar) {
          Text("Pior dia: \(Format.fullDay(worst.date)) · \(Format.brl(worst.value, short: true))")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .privacySensitive()
        }
        MonthsList(red: red, count: 6)
      }
      Divider()
      BillsList(summary: summary)
      Spacer(minLength: 0)
      UpdatedAt(summary: summary)
    }
  }
}

private struct RectangularView: View {
  let summary: Summary

  var body: some View {
    VStack(alignment: .leading, spacing: 1) {
      Text("Saldo \(Format.brl(summary.saldoHoje, short: true))")
        .font(.headline)
        .privacySensitive()
      if let red = summary.marVermelho, !Format.isZero(red.precisaEntrar) {
        Text("Verde: falta \(Format.brl(red.precisaEntrar, short: true))")
          .font(.caption)
          .privacySensitive()
        if let first = red.primeiroMesNoVermelho {
          Text("vermelho desde \(Format.month(first))").font(.caption2)
        }
      } else if let next = summary.proximasContas.first {
        Text("\(next.description) · \(Format.day(next.dueDate))")
          .font(.caption)
          .lineLimit(1)
        Text(Format.brl(next.amount, short: true)).font(.caption).privacySensitive()
      } else if let end = summary.saldoFimDoMes {
        Text("Fim do mês \(Format.brl(end, short: true))").font(.caption).privacySensitive()
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct FinSightWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: SummaryEntry

  var body: some View {
    Group {
      if let summary = entry.summary {
        switch family {
        case .systemMedium: MediumView(summary: summary)
        case .systemLarge: LargeView(summary: summary)
        case .accessoryRectangular: RectangularView(summary: summary)
        case .accessoryInline:
          if let red = summary.marVermelho, !Format.isZero(red.precisaEntrar) {
            Text("Saldo \(Format.brl(summary.saldoHoje, short: true)) · falta \(Format.brl(red.precisaEntrar, short: true))")
              .privacySensitive()
          } else {
            Text("Saldo \(Format.brl(summary.saldoHoje, short: true))").privacySensitive()
          }
        default: SmallView(summary: summary)
        }
      } else {
        EmptyState()
      }
    }
    .containerBackground(for: .widget) { Color.clear }
  }
}

struct FinSightWidget: Widget {
  // Must match `_iOSWidgetKind` in widget_sync.dart.
  let kind = "FinSightWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: SummaryProvider()) { entry in
      FinSightWidgetView(entry: entry)
    }
    .configurationDisplayName("FinSight")
    .description("Saldo, quanto falta para ficar no verde nos próximos meses e as próximas contas.")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
  }
}

@main
struct FinSightWidgetBundle: WidgetBundle {
  var body: some Widget {
    FinSightWidget()
  }
}
