import WidgetKit
import CoreData

struct ExpenseWidgetProvider: TimelineProvider {

    func placeholder(in context: Context) -> ExpenseWidgetEntry {
        ExpenseWidgetEntry(
            date: Date(),
            lastFuelDate: Date(),
            lastFuelCost: 82.50,
            lastFuelLiters: 55.0,
            monthlyTotal: 245.80,
            monthName: monthName(for: Date())
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ExpenseWidgetEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ExpenseWidgetEntry>) -> Void) {
        let entry = makeEntry()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    // MARK: - Private

    private func makeEntry() -> ExpenseWidgetEntry {
        let ctx = PersistenceController.shared.container.viewContext
        let now = Date()
        let cal = Calendar.current
        guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)) else {
            return ExpenseWidgetEntry(date: now, lastFuelDate: nil, lastFuelCost: 0,
                                     lastFuelLiters: 0, monthlyTotal: 0, monthName: monthName(for: now))
        }
        let monthPredicate = NSPredicate(format: "date >= %@ AND date <= %@", monthStart as NSDate, now as NSDate)

        // Last fuel entry
        let fuelReq = NSFetchRequest<FuelEntry>(entityName: "FuelEntry")
        fuelReq.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        fuelReq.fetchLimit = 1
        let lastFuel = (try? ctx.fetch(fuelReq))?.first

        // Monthly totals
        var monthly: Double = 0

        let fuelMonthReq: NSFetchRequest<NSDictionary> = NSFetchRequest(entityName: "FuelEntry")
        fuelMonthReq.predicate = monthPredicate
        fuelMonthReq.resultType = .dictionaryResultType
        fuelMonthReq.propertiesToFetch = ["totalCost"]
        if let rows = try? ctx.fetch(fuelMonthReq) {
            monthly += rows.reduce(0.0) { $0 + (($1["totalCost"] as? Double) ?? 0) }
        }

        for entity in ["GasEntry", "ServiceEntry", "OtherEntry"] {
            let req: NSFetchRequest<NSDictionary> = NSFetchRequest(entityName: entity)
            req.predicate = monthPredicate
            req.resultType = .dictionaryResultType
            req.propertiesToFetch = ["cost"]
            if entity == "GasEntry" {
                req.propertiesToFetch = ["costPerBottle", "bottleCount"]
                if let rows = try? ctx.fetch(req) {
                    monthly += rows.reduce(0.0) {
                        $0 + (($1["costPerBottle"] as? Double) ?? 0) * (($1["bottleCount"] as? Double) ?? 0)
                    }
                }
            } else if let rows = try? ctx.fetch(req) {
                monthly += rows.reduce(0.0) { $0 + (($1["cost"] as? Double) ?? 0) }
            }
        }

        return ExpenseWidgetEntry(
            date: now,
            lastFuelDate: lastFuel?.date,
            lastFuelCost: lastFuel?.totalCost ?? 0,
            lastFuelLiters: lastFuel?.liters ?? 0,
            monthlyTotal: monthly,
            monthName: monthName(for: now)
        )
    }

    private func monthName(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        f.locale = Locale(identifier: "de_DE")
        return f.string(from: date)
    }
}
