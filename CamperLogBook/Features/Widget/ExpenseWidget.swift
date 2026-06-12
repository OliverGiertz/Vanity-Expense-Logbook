import WidgetKit
import SwiftUI

// NOTE: Diese Datei liegt im Haupt-App-Bundle und wird von dort aus dem
// Widget Extension Target hinzugefügt (Target Membership).
// @main darf NICHT hier stehen – es wird im Widget Extension Target über
// eine separate WidgetBundle-Datei gesetzt. Siehe WIDGET_SETUP.md.
struct ExpenseWidget: Widget {
    let kind: String = "ExpenseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ExpenseWidgetProvider()) { entry in
            ExpenseWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Vanity Ausgaben")
        .description("Monatliche Ausgaben und letzter Tankeintrag.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
