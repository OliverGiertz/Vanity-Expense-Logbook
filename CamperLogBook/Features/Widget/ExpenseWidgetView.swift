import SwiftUI
import WidgetKit

struct ExpenseWidgetView: View {
    let entry: ExpenseWidgetEntry

    @Environment(\.widgetFamily) private var family

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.locale = Locale(identifier: "de_DE")
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.locale = Locale(identifier: "de_DE")
        return f
    }()

    var body: some View {
        switch family {
        case .systemSmall:  smallView
        case .systemMedium: mediumView
        default:            smallView
        }
    }

    // MARK: - Small

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Vanity Expense")
                .font(.caption2)
                .foregroundColor(.secondary)

            Spacer()

            Text(formatted(entry.monthlyTotal))
                .font(.title2.bold())
                .minimumScaleFactor(0.7)

            Text(entry.monthName)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
    }

    // MARK: - Medium

    private var mediumView: some View {
        HStack(spacing: 0) {
            // Left: monthly
            VStack(alignment: .leading, spacing: 4) {
                Text("Vanity Expense")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatted(entry.monthlyTotal))
                    .font(.title2.bold())
                    .minimumScaleFactor(0.7)
                Text(entry.monthName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            Divider()

            // Right: last fuel
            VStack(alignment: .leading, spacing: 4) {
                Label("Letzte Tankung", systemImage: "fuelpump.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                if let fuelDate = entry.lastFuelDate {
                    Text(formatted(entry.lastFuelCost))
                        .font(.headline.bold())
                        .minimumScaleFactor(0.7)
                    Text(String(format: "%.1f L · %@", entry.lastFuelLiters,
                                Self.dateFormatter.string(from: fuelDate)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("–")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .background(Color(.systemBackground))
    }

    private func formatted(_ value: Double) -> String {
        (Self.currencyFormatter.string(from: NSNumber(value: value)) ?? "0,00") + " €"
    }
}
