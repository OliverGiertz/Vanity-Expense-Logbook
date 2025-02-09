import SwiftUI

enum EntryType: String, CaseIterable, Identifiable {
    case fuel = "Tankbeleg"
    case gas = "Gaskosten"
    case service = "Ver-/Entsorgung"
    case other = "Sonstige Kosten"
    
    var id: String { self.rawValue }
}

struct EntryView: View {
    @State private var selectedEntry: EntryType = .fuel
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("Eintragstyp", selection: $selectedEntry) {
                    ForEach(EntryType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Je nach Auswahl den entsprechenden Eingabeformular anzeigen
                switch selectedEntry {
                case .fuel:
                    FuelEntryForm()
                case .gas:
                    GasEntryForm()
                case .service:
                    ServiceEntryForm()
                case .other:
                    OtherEntryForm()
                }
                Spacer()
            }
            .navigationTitle("Kosten Eintrag")
        }
    }
}

struct EntryView_Previews: PreviewProvider {
    static var previews: some View {
        EntryView()
    }
}
