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
    // The app reloads the timeline after every change; the hourly re-read
    // only keeps "hoje/amanhã" labels right across midnight.
    let entry = SummaryEntry(date: Date(), summary: Summary.load())
    completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600))))
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

// MARK: - Mar vermelho

private struct RedSeaHeadline: View {
  let red: Summary.RedSea

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      if Format.isZero(red.precisaEntrar) {
        Text("Caixa no verde").font(.headline).foregroundStyle(saldoGreen)
        Text("nos próximos \(red.horizonteMeses) meses").font(.caption2).foregroundStyle(.secondary)
      } else {
        Text("Para ficar no verde").font(.caption2).foregroundStyle(.secondary)
        Text(Format.brl(red.precisaEntrar, short: true))
          .font(.title3)
          .bold()
          .minimumScaleFactor(0.6)
          .lineLimit(1)
          .foregroundStyle(saldoRed)
          .privacySensitive()
        Text("precisa entrar").font(.caption2).foregroundStyle(.secondary)
        if let worst = red.piorDia {
          Text("pior dia: \(Format.fullDay(worst.date))")
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
        }
      }
    }
  }
}

private struct RedSeaMonths: View {
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

struct RedSeaWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: SummaryEntry

  var body: some View {
    Group {
      if let red = entry.summary?.marVermelho {
        switch family {
        case .systemMedium:
          HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading) {
              Text("Mar vermelho").font(.caption).bold()
              RedSeaHeadline(red: red)
              Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            RedSeaMonths(red: red, count: 6).frame(maxWidth: .infinity)
          }
        case .accessoryRectangular:
          VStack(alignment: .leading, spacing: 1) {
            if Format.isZero(red.precisaEntrar) {
              Text("Caixa no verde ✓").font(.headline)
              Text("próximos \(red.horizonteMeses) meses").font(.caption)
            } else {
              Text("Verde: falta \(Format.brl(red.precisaEntrar, short: true))")
                .font(.headline)
                .privacySensitive()
              if let first = red.primeiroMesNoVermelho {
                Text("vermelho a partir de \(Format.month(first))").font(.caption)
              }
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        case .accessoryInline:
          if Format.isZero(red.precisaEntrar) {
            Text("Caixa no verde ✓")
          } else {
            Text("Falta \(Format.brl(red.precisaEntrar, short: true)) p/ verde").privacySensitive()
          }
        default:
          VStack(alignment: .leading, spacing: 4) {
            Text("Mar vermelho").font(.caption).bold()
            RedSeaHeadline(red: red)
            Spacer(minLength: 0)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      } else {
        EmptyState()
      }
    }
    .containerBackground(for: .widget) { Color.clear }
  }
}

struct RedSeaWidget: Widget {
  // Must match `_iOSRedSeaKind` in widget_sync.dart.
  let kind = "FinSightRedSea"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: SummaryProvider()) { entry in
      RedSeaWidgetView(entry: entry)
    }
    .configurationDisplayName("Mar vermelho")
    .description("Quanto dinheiro novo precisa entrar para o saldo ficar no verde nos próximos meses.")
    .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
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
    RedSeaWidget()
  }
}
