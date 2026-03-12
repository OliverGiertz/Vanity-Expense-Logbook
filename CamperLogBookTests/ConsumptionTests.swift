import Testing
import Foundation
import CoreData
@testable import CamperLogBook

@Suite("FuelConsumptionCalculator")
struct ConsumptionTests {

    // MARK: - Helpers

    private func makeEntry(
        context: NSManagedObjectContext,
        daysOffset: Int,
        km: Int64,
        liters: Double,
        isFull: Bool = true
    ) -> FuelEntry {
        let entry = FuelEntry(context: context)
        entry.id = UUID()
        entry.date = Calendar.current.date(byAdding: .day, value: daysOffset, to: Date())!  // swiftlint:disable:this force_unwrapping
        entry.currentKm = km
        entry.liters = liters
        entry.isFull = isFull
        entry.isDiesel = true
        entry.isAdBlue = false
        entry.costPerLiter = 1.8
        entry.totalCost = liters * 1.8
        return entry
    }

    // MARK: - Tests

    /// Two consecutive full fill-ups → straightforward consumption calculation.
    @Test func test_fullFillOnly_correctConsumption() throws {
        let stack = CoreDataTestStack()
        let ctx = stack.context

        // 100 km driven, 12.7 L filled → 12.7 L/100 km
        let e1 = makeEntry(context: ctx, daysOffset: 0, km: 10_000, liters: 50.0, isFull: true)
        let e2 = makeEntry(context: ctx, daysOffset: 1, km: 10_100, liters: 12.7, isFull: true)
        try ctx.save()

        let sortedAsc = [e1, e2].sorted { $0.date < $1.date }
        let avg = FuelConsumptionCalculator.averageConsumption(from: sortedAsc)

        let expected = (12.7 / 100.0) * 100 // 12.7 L/100 km
        #expect(avg != nil)
        #expect(abs(avg! - expected) < 0.001) // swiftlint:disable:this force_unwrapping
    }

    /// Full, partial, full → liters of all entries between the two full fills are summed.
    @Test func test_partialFillIgnored() throws {
        let stack = CoreDataTestStack()
        let ctx = stack.context

        // e1: full tank at 10000 km
        // e2: partial fill at 10050 km, 10 L
        // e3: full tank at 10200 km, 15 L
        // interval: km = 200, liters = 10 + 15 = 25 → 12.5 L/100 km
        let e1 = makeEntry(context: ctx, daysOffset: 0, km: 10_000, liters: 40.0, isFull: true)
        let e2 = makeEntry(context: ctx, daysOffset: 1, km: 10_050, liters: 10.0, isFull: false)
        let e3 = makeEntry(context: ctx, daysOffset: 2, km: 10_200, liters: 15.0, isFull: true)
        try ctx.save()

        let sortedAsc = [e1, e2, e3].sorted { $0.date < $1.date }
        let intervals = FuelConsumptionCalculator.intervals(from: sortedAsc)

        #expect(intervals.count == 1)
        let interval = intervals[0]
        #expect(interval.kmDiff == 200)
        #expect(abs(interval.totalLiters - 25.0) < 0.001)
        #expect(abs(interval.consumptionPer100km - 12.5) < 0.001)
    }

    /// Only a partial fill with no preceding full fill → no interval, nil returned.
    @Test func test_partialFillNoInterval() throws {
        let stack = CoreDataTestStack()
        let ctx = stack.context

        let e1 = makeEntry(context: ctx, daysOffset: 0, km: 10_000, liters: 10.0, isFull: false)
        try ctx.save()

        let sortedAsc = [e1]
        let avg = FuelConsumptionCalculator.averageConsumption(from: sortedAsc)
        #expect(avg == nil)
    }

    /// Only one full fill-up → no interval can be calculated → nil.
    @Test func test_twoFullFillsRequired() throws {
        let stack = CoreDataTestStack()
        let ctx = stack.context

        let e1 = makeEntry(context: ctx, daysOffset: 0, km: 10_000, liters: 50.0, isFull: true)
        try ctx.save()

        let sortedAsc = [e1]
        let avg = FuelConsumptionCalculator.averageConsumption(from: sortedAsc)
        #expect(avg == nil)
    }

    /// Multiple intervals are averaged correctly across their total km/liters.
    @Test func test_multipleIntervals_averaged() throws {
        let stack = CoreDataTestStack()
        let ctx = stack.context

        // Interval 1: 100 km, 12 L → 12 L/100 km
        // Interval 2: 200 km, 26 L → 13 L/100 km
        // Total: 300 km, 38 L → 38/300*100 ≈ 12.667 L/100 km
        let e1 = makeEntry(context: ctx, daysOffset: 0, km: 10_000, liters: 40.0, isFull: true)
        let e2 = makeEntry(context: ctx, daysOffset: 1, km: 10_100, liters: 12.0, isFull: true)
        let e3 = makeEntry(context: ctx, daysOffset: 2, km: 10_300, liters: 26.0, isFull: true)
        try ctx.save()

        let sortedAsc = [e1, e2, e3].sorted { $0.date < $1.date }
        let avg = FuelConsumptionCalculator.averageConsumption(from: sortedAsc)
        let expected = (38.0 / 300.0) * 100
        #expect(avg != nil)
        #expect(abs(avg! - expected) < 0.001) // swiftlint:disable:this force_unwrapping
    }
}
