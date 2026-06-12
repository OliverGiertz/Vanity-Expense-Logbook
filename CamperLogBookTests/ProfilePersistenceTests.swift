import Testing
import Foundation
import CoreData
@testable import CamperLogBook

@Suite("ProfilePersistence")
struct ProfilePersistenceTests {

    // MARK: - Tests

    @Test func test_vehicleProfile_saveAndFetch() throws {
        let stack = CoreDataTestStack()
        let profile = VehicleProfile(context: stack.context)
        profile.id = UUID()
        profile.name = "Test Van"
        profile.tankVolume = 70.0
        try stack.context.save()

        let results = try stack.context.fetch(VehicleProfile.fetchRequestProfile())
        #expect(results.count == 1)
        #expect(results[0].name == "Test Van")
        #expect(abs(results[0].tankVolume - 70.0) < 0.001)
    }

    @Test func test_vehicleProfile_updateName_persistsChange() throws {
        let stack = CoreDataTestStack()
        let profile = VehicleProfile(context: stack.context)
        profile.id = UUID()
        profile.name = "Old Name"
        profile.tankVolume = 60.0
        try stack.context.save()

        profile.name = "New Name"
        try stack.context.save()

        let results = try stack.context.fetch(VehicleProfile.fetchRequestProfile())
        #expect(results.first?.name == "New Name")
    }

    @Test func test_vehicleProfile_zeroTankVolume_isSaved() throws {
        let stack = CoreDataTestStack()
        let profile = VehicleProfile(context: stack.context)
        profile.id = UUID()
        profile.name = "No Tank Info"
        profile.tankVolume = 0.0
        try stack.context.save()

        let results = try stack.context.fetch(VehicleProfile.fetchRequestProfile())
        #expect(results.first?.tankVolume == 0.0)
    }

    @Test func test_vehicleProfile_delete_removesFromStore() throws {
        let stack = CoreDataTestStack()
        let profile = VehicleProfile(context: stack.context)
        profile.id = UUID()
        profile.name = "To Delete"
        try stack.context.save()

        stack.context.delete(profile)
        try stack.context.save()

        let results = try stack.context.fetch(VehicleProfile.fetchRequestProfile())
        #expect(results.isEmpty)
    }
}
