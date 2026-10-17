import SwiftUI
import WidgetKit

// The app writes `/insights/summary` into the shared App Group (see
// lib/core/home_widget/widget_sync.dart) whenever its data changes; the
// widget only reads that snapshot — no network, no session here.

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

  let asOf: String
  let saldoHoje: String
  let saldoFimDoMes: String?
  let menorSaldo: Lowest?
  let podeGuardar: String
  let proximasContas: [Bill]

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
    ]
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
    // The app reloads the timeline after every change; the hourly re-read
    // only keeps "hoje/amanhã" labels right across midnight.
    let entry = SummaryEntry(date: Date(), summary: Summary.load())
    completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600))))
  }
}

// MARK: - Views

private let saldoGreen = Color(red: 0.18, green: 0.55, blue: 0.34)
private let saldoRed = Color(red: 0.82, green: 0.33, blue: 0.12)

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
  var big: Bool = true

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text("Saldo hoje").font(.caption2).foregroundStyle(.secondary)
      Text(Format.brl(summary.saldoHoje))
        .font(big ? .title3 : .headline)
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

private struct SmallView: View {
  let summary: Summary

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      SaldoBlock(summary: summary)
      Spacer(minLength: 0)
      if NSDecimalNumber(string: summary.podeGuardar).compare(NSDecimalNumber.zero) == .orderedDescending {
        Text("Dá para guardar \(Format.brl(summary.podeGuardar, short: true))")
          .font(.caption2)
          .foregroundStyle(saldoGreen)
          .privacySensitive()
      }
      Text(Format.updatedAt(summary.asOf)).font(.system(size: 9)).foregroundStyle(.tertiary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct MediumView: View {
  let summary: Summary

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      SmallView(summary: summary)
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
        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
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
      if let next = summary.proximasContas.first {
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
        case .accessoryRectangular: RectangularView(summary: summary)
        case .accessoryInline:
          Text("Saldo \(Format.brl(summary.saldoHoje, short: true))").privacySensitive()
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
    .configurationDisplayName("Saldo e contas")
    .description("Seu saldo, como o mês termina e as próximas contas.")
    .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
  }
}

@main
struct FinSightWidgetBundle: WidgetBundle {
  var body: some Widget {
    FinSightWidget()
  }
}
