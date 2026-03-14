import WidgetKit
import SwiftUI

// NOTE: Diese Datei ist für das separate Widget-Extension-Target bestimmt.
// Anleitung zur Einrichtung: siehe WIDGET_SETUP.md in diesem Ordner.

@main
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
