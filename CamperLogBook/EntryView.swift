import SwiftUI

enum EntryType: String, CaseIterable, Identifiable {
    case tanken = "Tanken"
    case gas = "Gas"
    case service = "Ver- / Entsorgung"
    case sonstiges = "Sonstiges"
    
    var id: String { self.rawValue }
}

struct EntryView: View {
    @State private var selectedEntry: EntryType = .tanken
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                Text("Kosten Typ auswählen:")
                    .font(.headline)
                    .padding(.top, 16)
                    .padding(.horizontal)
                
                Picker("Eintragstyp", selection: $selectedEntry) {
                    ForEach(EntryType.allCases) { type in
                        Text(type.rawValue)
                            .font(.system(size: 28, weight: .bold))
                            .tag(type)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                Divider()
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                
                // Je nach Auswahl den entsprechenden Eingabeformular anzeigen
                Group {
                    switch selectedEntry {
                    case .tanken:
                        FuelEntryForm()
                    case .gas:
                        GasEntryForm()
                    case .service:
                        ServiceEntryForm()
                    case .sonstiges:
                        OtherEntryForm()
                    }
                }
                .padding(.horizontal)
                
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
