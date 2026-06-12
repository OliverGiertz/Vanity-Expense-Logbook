import Testing
import Foundation
import CoreData
@testable import CamperLogBook

@Suite("ExpenseCalculation")
struct ExpenseCalculationTests {

    // MARK: - Tests

    @Test func test_totalCostAllTypes_correctSum() throws {
        let stack = CoreDataTestStack()
        let ctx = stack.context
        let now = Date()

        let fuel = FuelEntry(context: ctx)
        fuel.id = UUID(); fuel.date = now; fuel.totalCost = 50.0; fuel.isDiesel = true

        let gas = GasEntry(context: ctx)
        gas.id = UUID(); gas.date = now; gas.costPerBottle = 30.0; gas.bottleCount = 2

        let service = ServiceEntry(context: ctx)
        service.id = UUID(); service.date = now; service.cost = 20.0

        let other = OtherEntry(context: ctx)
        other.id = UUID(); other.date = now; other.cost = 15.0; other.category = "Test"

        try ctx.save()

        let fuelTotal    = try ctx.fetch(FuelEntry.fetchAll()).reduce(0.0)    { $0 + $1.totalCost }
        let gasTotal     = try ctx.fetch(GasEntry.fetchAll()).reduce(0.0)     { $0 + ($1.costPerBottle * Double($1.bottleCount)) }
        let serviceTotal = try ctx.fetch(ServiceEntry.fetchAll()).reduce(0.0) { $0 + $1.cost }
        let otherTotal   = try ctx.fetch(OtherEntry.fetchAll()).reduce(0.0)   { $0 + $1.cost }

        // 50 + 60 + 20 + 15 = 145
        #expect(abs(fuelTotal + gasTotal + serviceTotal + otherTotal - 145.0) < 0.001)
    }

    @Test func test_emptyDataSet_returnsZero() throws {
        let stack = CoreDataTestStack()
        let total = try stack.context.fetch(FuelEntry.fetchAll()).reduce(0.0) { $0 + $1.totalCost }
        #expect(total == 0.0)
    }

    @Test func test_singleEntry_totalCostIsExact() throws {
        let stack = CoreDataTestStack()
        let entry = FuelEntry(context: stack.context)
        entry.id = UUID(); entry.date = Date()
        entry.liters = 40.0; entry.costPerLiter = 1.89
        entry.totalCost = 40.0 * 1.89    // 75.6
        entry.isDiesel = true
        try stack.context.save()

        let results = try stack.context.fetch(FuelEntry.fetchAll())
        #expect(results.count == 1)
        #expect(abs(results[0].totalCost - 75.6) < 0.001)
    }

    @Test func test_monthlyCostAggregation_groupsByMonth() throws {
        let stack = CoreDataTestStack()
        let cal = Calendar.current
        let jan = cal.date(from: DateComponents(year: 2024, month: 1, day: 15)) ?? Date()
        let feb = cal.date(from: DateComponents(year: 2024, month: 2, day: 15)) ?? Date()

        let e1 = FuelEntry(context: stack.context)
        e1.id = UUID(); e1.date = jan; e1.totalCost = 60.0; e1.isDiesel = true

        let e2 = FuelEntry(context: stack.context)
        e2.id = UUID(); e2.date = feb; e2.totalCost = 70.0; e2.isDiesel = true

        try stack.context.save()

        let results = try stack.context.fetch(FuelEntry.fetchAll())
        let grouped = Dictionary(grouping: results) { entry -> String in
            let comps = cal.dateComponents([.year, .month], from: entry.date)
            return "\(comps.year ?? 0)-\(comps.month ?? 0)"
        }

        #expect(grouped.keys.count == 2)
        let janCost = grouped["2024-1"]?.reduce(0.0) { $0 + $1.totalCost } ?? 0.0
        let febCost = grouped["2024-2"]?.reduce(0.0) { $0 + $1.totalCost } ?? 0.0
        #expect(abs(janCost - 60.0) < 0.001)
        #expect(abs(febCost - 70.0) < 0.001)
    }

    @Test func test_dateRange_excludesOutOfRangeEntries() throws {
        let stack = CoreDataTestStack()
        let cal = Calendar.current
        let inRange  = cal.date(from: DateComponents(year: 2024, month: 6, day: 15)) ?? Date()
        let outRange = cal.date(from: DateComponents(year: 2023, month: 1,  day: 1))  ?? Date()

        let inside = ServiceEntry(context: stack.context)
        inside.id = UUID(); inside.date = inRange; inside.cost = 99.0

        let outside = ServiceEntry(context: stack.context)
        outside.id = UUID(); outside.date = outRange; outside.cost = 200.0

        try stack.context.save()

        let rangeStart = cal.date(from: DateComponents(year: 2024, month: 1, day: 1)) ?? Date()
        let rangeEnd   = cal.date(from: DateComponents(year: 2024, month: 12, day: 31)) ?? Date()
        let req = ServiceEntry.fetchAll()
        req.predicate = NSPredicate(format: "date >= %@ AND date <= %@", rangeStart as NSDate, rangeEnd as NSDate)
        let results = try stack.context.fetch(req)

        #expect(results.count == 1)
        #expect(abs(results[0].cost - 99.0) < 0.001)
    }
}
