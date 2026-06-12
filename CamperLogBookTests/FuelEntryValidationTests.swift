import Testing
import Foundation
import CoreData
@testable import CamperLogBook

@Suite("FuelEntryValidation")
struct FuelEntryValidationTests {

    // MARK: - Helpers

    private func makeFuelEntry(
        context: NSManagedObjectContext,
        daysOffset: Int,
        km: Int64,
        liters: Double,
        isFull: Bool = true,
        isDiesel: Bool = true
    ) -> FuelEntry {
        let entry = FuelEntry(context: context)
        entry.id = UUID()
        entry.date = Calendar.current.date(byAdding: .day, value: daysOffset, to: Date()) ?? Date()
        entry.currentKm = km
        entry.liters = liters
        entry.isFull = isFull
        entry.isDiesel = isDiesel
        entry.isAdBlue = !isDiesel
        entry.fuelType = isDiesel ? "Diesel" : "AdBlue"
        entry.costPerLiter = 1.89
        entry.totalCost = liters * 1.89
        return entry
    }

    // MARK: - Tests

    @Test func test_validEntry_savesSuccessfully() throws {
        let stack = CoreDataTestStack()
        _ = makeFuelEntry(context: stack.context, daysOffset: 0, km: 50_000, liters: 40.0)
        try stack.context.save()

        let results = try stack.context.fetch(FuelEntry.fetchAll())
        #expect(results.count == 1)
        #expect(results[0].currentKm == 50_000)
    }

    @Test func test_zeroKm_savedButNoConsumptionInterval() throws {
        let stack = CoreDataTestStack()
        let entry = makeFuelEntry(context: stack.context, daysOffset: 0, km: 0, liters: 40.0)
        try stack.context.save()

        let intervals = FuelConsumptionCalculator.intervals(from: [entry])
        #expect(intervals.isEmpty)
    }

    @Test func test_decreasingKm_producesNoInterval() throws {
        let stack = CoreDataTestStack()
        let e1 = makeFuelEntry(context: stack.context, daysOffset: 0, km: 10_200, liters: 40.0)
        let e2 = makeFuelEntry(context: stack.context, daysOffset: 1, km: 10_100, liters: 30.0)
        try stack.context.save()

        let sorted = [e1, e2].sorted { $0.date < $1.date }
        let intervals = FuelConsumptionCalculator.intervals(from: sorted)
        #expect(intervals.isEmpty)
    }

    @Test func test_partialFills_sumedBetweenFullFills() throws {
        let stack = CoreDataTestStack()
        // Full at 10000 km
        let e1 = makeFuelEntry(context: stack.context, daysOffset: 0, km: 10_000, liters: 40.0)
        // Partial at 10050 km, 10 L → not a new interval start
        let e2 = makeFuelEntry(context: stack.context, daysOffset: 1, km: 10_050, liters: 10.0, isFull: false)
        // Full at 10200 km, 20 L → 200 km, 30 L total → 15.0 L/100 km
        let e3 = makeFuelEntry(context: stack.context, daysOffset: 2, km: 10_200, liters: 20.0)
        try stack.context.save()

        let sorted = [e1, e2, e3].sorted { $0.date < $1.date }
        let intervals = FuelConsumptionCalculator.intervals(from: sorted)
        #expect(intervals.count == 1)
        #expect(abs(intervals[0].totalLiters - 30.0) < 0.001)
        #expect(abs(intervals[0].consumptionPer100km - 15.0) < 0.001)
    }

    @Test func test_adBlue_notIncludedInDieselConsumptionCalculation() throws {
        let stack = CoreDataTestStack()
        let diesel1 = makeFuelEntry(context: stack.context, daysOffset: 0, km: 10_000, liters: 40.0, isDiesel: true)
        _ = makeFuelEntry(context: stack.context, daysOffset: 1, km: 10_050, liters: 5.0, isFull: false, isDiesel: false)
        let diesel2 = makeFuelEntry(context: stack.context, daysOffset: 2, km: 10_200, liters: 12.0, isDiesel: true)
        try stack.context.save()

        // Calculator receives only diesel entries (as the app filters them)
        let dieselEntries = [diesel1, diesel2].sorted { $0.date < $1.date }
        let intervals = FuelConsumptionCalculator.intervals(from: dieselEntries)
        #expect(intervals.count == 1)
        // Only 12 L counted, not the AdBlue 5 L
        #expect(abs(intervals[0].totalLiters - 12.0) < 0.001)
    }
}
