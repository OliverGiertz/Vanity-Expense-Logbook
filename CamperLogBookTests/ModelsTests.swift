import Testing
import CoreData
@testable import CamperLogBook

@Suite("Models")
struct ModelsTests {

    // MARK: - willSave GPS Rounding

    @Test func fuelEntry_willSave_roundsTo4DecimalPlaces() throws {
        let stack = CoreDataTestStack()
        let entry = FuelEntry(context: stack.context)
        entry.id = UUID()
        entry.date = Date()
        entry.latitude = 48.123456789   // rounds to 48.1235
        entry.longitude = 11.987654321  // rounds to 11.9877
        try stack.context.save()

        #expect(abs(entry.roundedLatitude - 48.1235) < 0.00001)
        #expect(abs(entry.roundedLongitude - 11.9877) < 0.00001)
    }

    @Test func gasEntry_willSave_roundsTo4DecimalPlaces() throws {
        let stack = CoreDataTestStack()
        let entry = GasEntry(context: stack.context)
        entry.id = UUID()
        entry.date = Date()
        entry.latitude = 52.5200001     // rounds to 52.52
        entry.longitude = 13.4050005   // rounds to 13.405
        try stack.context.save()

        #expect(abs(entry.roundedLatitude - 52.52) < 0.00001)
        #expect(abs(entry.roundedLongitude - 13.405) < 0.00001)
    }

    @Test func serviceEntry_willSave_roundsTo4DecimalPlaces() throws {
        let stack = CoreDataTestStack()
        let entry = ServiceEntry(context: stack.context)
        entry.id = UUID()
        entry.date = Date()
        entry.latitude = 48.0001234     // rounds to 48.0001
        entry.longitude = 11.9998765   // rounds to 11.9999
        try stack.context.save()

        #expect(abs(entry.roundedLatitude - 48.0001) < 0.000001)
        #expect(abs(entry.roundedLongitude - 11.9999) < 0.000001)
    }

    @Test func otherEntry_willSave_roundsTo4DecimalPlaces() throws {
        let stack = CoreDataTestStack()
        let entry = OtherEntry(context: stack.context)
        entry.id = UUID()
        entry.date = Date()
        entry.category = "Test"
        entry.latitude = 0.000049999   // rounds to 0.0
        entry.longitude = 179.999950001 // rounds to 180.0
        try stack.context.save()

        #expect(abs(entry.roundedLatitude - 0.0) < 0.00001)
        #expect(abs(entry.roundedLongitude - 180.0) < 0.00001)
    }

    @Test func fuelEntry_willSave_zeroCoordinates_stayZero() throws {
        let stack = CoreDataTestStack()
        let entry = FuelEntry(context: stack.context)
        entry.id = UUID()
        entry.date = Date()
        entry.latitude = 0.0
        entry.longitude = 0.0
        try stack.context.save()

        #expect(entry.roundedLatitude == 0.0)
        #expect(entry.roundedLongitude == 0.0)
    }

    // MARK: - fetchAll Sort Order

    @Test func fuelEntry_fetchAll_sortsByDateDescending() throws {
        let stack = CoreDataTestStack()
        let now = Date()
        let yesterday = now.addingTimeInterval(-86_400)

        let older = FuelEntry(context: stack.context)
        older.id = UUID()
        older.date = yesterday

        let newer = FuelEntry(context: stack.context)
        newer.id = UUID()
        newer.date = now

        try stack.context.save()

        let results = try stack.context.fetch(FuelEntry.fetchAll())
        #expect(results.count == 2)
        #expect(results[0].date >= results[1].date)
    }

    @Test func gasEntry_fetchAll_sortsByDateDescending() throws {
        let stack = CoreDataTestStack()
        let now = Date()
        let twoDaysAgo = now.addingTimeInterval(-2 * 86_400)

        let older = GasEntry(context: stack.context)
        older.id = UUID()
        older.date = twoDaysAgo

        let newer = GasEntry(context: stack.context)
        newer.id = UUID()
        newer.date = now

        try stack.context.save()

        let results = try stack.context.fetch(GasEntry.fetchAll())
        #expect(results.count == 2)
        #expect(results[0].date >= results[1].date)
    }
}
