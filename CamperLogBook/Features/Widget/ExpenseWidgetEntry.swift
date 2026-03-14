import WidgetKit

struct ExpenseWidgetEntry: TimelineEntry {
    let date: Date
    let lastFuelDate: Date?
    let lastFuelCost: Double
    let lastFuelLiters: Double
    let monthlyTotal: Double
    let monthName: String
}
