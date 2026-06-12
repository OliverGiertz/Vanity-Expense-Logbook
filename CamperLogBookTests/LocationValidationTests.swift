import Testing
import Foundation
import CoreData
import CoreLocation
@testable import CamperLogBook

@Suite("LocationValidation")
struct LocationValidationTests {

    // MARK: - LocatableEntry coordinate rounding

    @Test func test_coordinatePrecision_roundedToFourDecimalPlaces() throws {
        let stack = CoreDataTestStack()
        let entry = FuelEntry(context: stack.context)
        entry.id = UUID()
        entry.date = Date()
        entry.latitude  = 48.123456789   // should round to 48.1235
        entry.longitude = 11.987654321   // should round to 11.9877
        try stack.context.save()

        #expect(abs(entry.roundedLatitude  - 48.1235) < 0.00001)
        #expect(abs(entry.roundedLongitude - 11.9877) < 0.00001)
    }

    @Test func test_zeroCoordinate_savedCorrectly() throws {
        let stack = CoreDataTestStack()
        let entry = GasEntry(context: stack.context)
        entry.id = UUID()
        entry.date = Date()
        entry.latitude  = 0.0
        entry.longitude = 0.0
        try stack.context.save()

        #expect(entry.roundedLatitude  == 0.0)
        #expect(entry.roundedLongitude == 0.0)
    }

    @Test func test_allEntryTypes_coordinatesRounded() throws {
        let stack = CoreDataTestStack()
        let ctx = stack.context

        let fuel = FuelEntry(context: ctx)
        fuel.id = UUID(); fuel.date = Date()
        fuel.latitude = 51.50001; fuel.longitude = -0.10001

        let gas = GasEntry(context: ctx)
        gas.id = UUID(); gas.date = Date()
        gas.latitude = 48.13711; gas.longitude = 11.57542

        let service = ServiceEntry(context: ctx)
        service.id = UUID(); service.date = Date()
        service.latitude = 52.52001; service.longitude = 13.40499

        let other = OtherEntry(context: ctx)
        other.id = UUID(); other.date = Date(); other.category = "Test"
        other.latitude = 43.29695; other.longitude = 5.38107

        try ctx.save()

        // All rounded values must match to 4 decimal places
        let precision = 0.00005
        #expect(abs(fuel.roundedLatitude    - (51.50001 * 10_000).rounded() / 10_000) < precision)
        #expect(abs(gas.roundedLongitude    - (11.57542 * 10_000).rounded() / 10_000) < precision)
        #expect(abs(service.roundedLatitude - (52.52001 * 10_000).rounded() / 10_000) < precision)
        #expect(abs(other.roundedLongitude  - (5.38107  * 10_000).rounded() / 10_000) < precision)
    }
}
