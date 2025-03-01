import SwiftUI
import CoreData

struct ProfileView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("showStartInfo") var showStartInfo: Bool = true

    // Fahrzeugprofil (angenommen, es gibt nur ein Profil)
    @FetchRequest(
        entity: VehicleProfile.entity(),
        sortDescriptors: []
    ) var profiles: FetchedResults<VehicleProfile>
    
    // Kategorien abrufen – nun ExpenseCategory
    @FetchRequest(
        entity: ExpenseCategory.entity(),
        sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)]
    ) var categories: FetchedResults<ExpenseCategory>
    
    @State private var licensePlate: String = ""
    @State private var brand: String = ""
    @State private var type: String = ""
    
    // Für die Eingabe einer neuen Kategorie
    @State private var newCategoryName: String = ""
    
    // State für Premium-Feature
    @ObservedObject private var premiumManager = PremiumFeatureManager.shared
    @State private var showPremiumBackupView = false
    @State private var showBackupFeatureView = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("App-Informationen")) {
                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                        if let releaseDate = Bundle.main.infoDictionary?["CFBundleReleaseDate"] as? String {
                            Text("Version \(version) (\(releaseDate))")
                        } else {
                            Text("Version \(version)")
                        }
                    } else {
                        Text("Version nicht verfügbar")
                    }
                }
                
                Section(header: Text("Fahrzeugdaten")) {
                    TextField("KFZ Kennzeichen", text: $licensePlate)
                    TextField("Automarke", text: $brand)
                    TextField("Fahrzeugtyp", text: $type)
                    Button("Profil speichern") {
                        saveProfile()
                    }
                }
                
                Section(header: Text("Kategorien verwalten")) {
                    List {
                        ForEach(categories, id: \.self) { category in
                            NavigationLink(destination: EditCategoryView(expenseCategory: category)) {
                                Text(category.name ?? "Unbekannt")
                            }
                        }
                        .onDelete(perform: deleteCategories)
                    }
                    HStack {
                        TextField("Neue Kategorie", text: $newCategoryName)
                        Button("Hinzufügen") {
                            addCategory()
                        }
                        .disabled(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                
                Section(header: Text("Datensicherung")) {
                    if premiumManager.isBackupFeatureUnlocked {
                        NavigationLink(destination: BackupRestoreView()) {
                            HStack {
                                Image(systemName: "externaldrive")
                                    .foregroundColor(.blue)
                                Text("Backup & Wiederherstellung")
                            }
                        }
                    } else {
                        Button(action: { showBackupFeatureView = true }) {
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.blue)
                                Text("Backup & Wiederherstellung")
                                Spacer()
                                Text("PREMIUM")
                                    .font(.caption)
                                    .padding(4)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
                
                Section(header: Text("Startseiten-Einstellungen")) {
                    Toggle("Startseite beim App-Start anzeigen", isOn: $showStartInfo)
                }
                
                Section(header: Text("Datenimport/-export")) {
                    NavigationLink(destination: ImportExportView()) {
                        Text("CSV Import/Export")
                    }
                }
                
                // Nur in DEBUG-Umgebung anzeigen
                #if DEBUG
                Section(header: Text("Debug-Optionen")) {
                    Button("Premium-Status zurücksetzen") {
                        premiumManager.resetPurchases()
                    }
                    .foregroundColor(.red)
                }
                #endif
            }
            .navigationTitle("Profil")
            .onAppear {
                loadProfile()
            }
            .sheet(isPresented: $showBackupFeatureView) {
                NavigationView {
                    PremiumFeatureView(
                        featureID: premiumManager.backupFeatureID,
                        featureName: "Backup & Wiederherstellung",
                        featureDescription: "Sichere deine Daten und Belege und stelle sie bei Bedarf wieder her",
                        featureIcon: "externaldrive.fill",
                        price: "4,99 €"
                    )
                }
            }
        }
    }
    
    private func loadProfile() {
        if let profile = profiles.first {
            licensePlate = profile.licensePlate
            brand = profile.brand
            type = profile.type
        }
    }
    
    private func saveProfile() {
        let profile: VehicleProfile
        if let existing = profiles.first {
            profile = existing
        } else {
            profile = VehicleProfile(context: viewContext)
            profile.id = UUID()
        }
        profile.licensePlate = licensePlate
        profile.brand = brand
        profile.type = type
        do {
            try viewContext.save()
        } catch {
            print("Error saving profile: \(error)")
        }
    }
    
    private func addCategory() {
        let trimmed = newCategoryName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let newCat = ExpenseCategory(context: viewContext)
        newCat.id = UUID()
        newCat.name = trimmed
        do {
            try viewContext.save()
            newCategoryName = ""
        } catch {
            print("Error adding category: \(error)")
        }
    }
    
    private func deleteCategories(offsets: IndexSet) {
        offsets.map { categories[$0] }.forEach(viewContext.delete)
        do {
            try viewContext.save()
        } catch {
            print("Error deleting categories: \(error)")
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}
