import Foundation

/// Shared, lazily-initialised formatters. Creating formatters is expensive —
/// reference these singletons instead of instantiating locally.
enum AppFormatters {

    // MARK: Date

    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        return f
    }()

    static let iso8601: ISO8601DateFormatter = ISO8601DateFormatter()

    // MARK: Number (de_DE locale)

    static let deDecimal2: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.usesGroupingSeparator = true
        return f
    }()

    static let deInteger: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 0
        f.usesGroupingSeparator = true
        return f
    }()

    static let deCurrency: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.numberStyle = .currency
        f.currencyCode = "EUR"
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()
}
