import Foundation
import CoreData

// MARK: - FuelEntry (Tankbeleg)
public class FuelEntry: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var date: Date
    @NSManaged public var isDiesel: Bool
    @NSManaged public var isAdBlue: Bool
    @NSManaged public var currentKm: Int64
    @NSManaged public var liters: Double
    @NSManaged public var costPerLiter: Double
    @NSManaged public var totalCost: Double
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var receiptData: Data?
    @NSManaged public var receiptType: String?
    
    // Neue Felder: Gerundete GPS-Werte
    @NSManaged public var roundedLatitude: Double
    @NSManaged public var roundedLongitude: Double

    // Neue Adresse-Information
    @NSManaged public var address: String?
}

extension FuelEntry {
    static func fetchAll() -> NSFetchRequest<FuelEntry> {
        let request: NSFetchRequest<FuelEntry> = FuelEntry.fetchRequest() as! NSFetchRequest<FuelEntry>
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        return request
    }
    
    public override func willSave() {
        super.willSave()
        let newRoundedLat = (latitude * 10000).rounded() / 10000
        let newRoundedLon = (longitude * 10000).rounded() / 10000
        if roundedLatitude != newRoundedLat {
            roundedLatitude = newRoundedLat
        }
        if roundedLongitude != newRoundedLon {
            roundedLongitude = newRoundedLon
        }
    }
}

// MARK: - GasEntry (Gaskosten)
public class GasEntry: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var date: Date
    @NSManaged public var costPerBottle: Double
    @NSManaged public var bottleCount: Int64
    @NSManaged public var receiptData: Data?
    @NSManaged public var receiptType: String?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    
    // Neue Felder
    @NSManaged public var roundedLatitude: Double
    @NSManaged public var roundedLongitude: Double

    // Neue Adresse-Information
    @NSManaged public var address: String?
}

extension GasEntry {
    static func fetchAll() -> NSFetchRequest<GasEntry> {
        let request: NSFetchRequest<GasEntry> = GasEntry.fetchRequest() as! NSFetchRequest<GasEntry>
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        return request
    }
    
    public override func willSave() {
        super.willSave()
        let newRoundedLat = (latitude * 10000).rounded() / 10000
        let newRoundedLon = (longitude * 10000).rounded() / 10000
        if roundedLatitude != newRoundedLat {
            roundedLatitude = newRoundedLat
        }
        if roundedLongitude != newRoundedLon {
            roundedLongitude = newRoundedLon
        }
    }
}

// MARK: - ServiceEntry (Ver- und Entsorgung)
public class ServiceEntry: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var date: Date
    @NSManaged public var isSupply: Bool
    @NSManaged public var isDisposal: Bool
    @NSManaged public var cost: Double
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var receiptData: Data?
    @NSManaged public var freshWater: Double
    
    // Neue Felder
    @NSManaged public var roundedLatitude: Double
    @NSManaged public var roundedLongitude: Double

    // Neue Adresse-Information
    @NSManaged public var address: String?
}

extension ServiceEntry {
    static func fetchAll() -> NSFetchRequest<ServiceEntry> {
        let request: NSFetchRequest<ServiceEntry> = ServiceEntry.fetchRequest() as! NSFetchRequest<ServiceEntry>
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        return request
    }
    
    public override func willSave() {
        super.willSave()
        let newRoundedLat = (latitude * 10000).rounded() / 10000
        let newRoundedLon = (longitude * 10000).rounded() / 10000
        if roundedLatitude != newRoundedLat {
            roundedLatitude = newRoundedLat
        }
        if roundedLongitude != newRoundedLon {
            roundedLongitude = newRoundedLon
        }
    }
}

// MARK: - OtherEntry (Sonstige Kosten)
public class OtherEntry: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var date: Date
    @NSManaged public var category: String
    @NSManaged public var details: String?
    @NSManaged public var cost: Double
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var receiptData: Data?
    @NSManaged public var receiptType: String?
    
    // Neue Felder
    @NSManaged public var roundedLatitude: Double
    @NSManaged public var roundedLongitude: Double

    // Neue Adresse-Information
    @NSManaged public var address: String?
}

extension OtherEntry {
    static func fetchAll() -> NSFetchRequest<OtherEntry> {
        let request: NSFetchRequest<OtherEntry> = OtherEntry.fetchRequest() as! NSFetchRequest<OtherEntry>
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        return request
    }
    
    public override func willSave() {
        super.willSave()
        let newRoundedLat = (latitude * 10000).rounded() / 10000
        let newRoundedLon = (longitude * 10000).rounded() / 10000
        if roundedLatitude != newRoundedLat {
            roundedLatitude = newRoundedLat
        }
        if roundedLongitude != newRoundedLon {
            roundedLongitude = newRoundedLon
        }
    }
}

// MARK: - VehicleProfile (Profil)
public class VehicleProfile: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var licensePlate: String
    @NSManaged public var brand: String
    @NSManaged public var type: String
}

extension VehicleProfile {
    static func fetchRequestProfile() -> NSFetchRequest<VehicleProfile> {
        let request: NSFetchRequest<VehicleProfile> = VehicleProfile.fetchRequest() as! NSFetchRequest<VehicleProfile>
        return request
    }
}
