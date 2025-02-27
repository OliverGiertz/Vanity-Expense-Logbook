import SwiftUI

enum EntryType: String, CaseIterable, Identifiable {
    case tanken = "Tanken"
    case gas = "Gas"
    case service = "Ver- / Entsorgung"
    case sonstiges = "Sonstiges"
    
    var id: String { self.rawValue }
}

struct EntryView: View {
    // Standardmäßig wird "Tanken" ausgewählt, also FuelEntryForm.
    @State private var selectedEntry: EntryType = .tanken
    @State private var navigate: Bool = false
    
    var body: some View {
        NavigationView {
            // Als Standardanzeige bleibt das FuelEntryForm
            FuelEntryForm()
                .navigationTitle("Kosten Eintrag")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button("Tanken") {
                                selectedEntry = .tanken
                                navigate = true
                            }
                            Button("Gas") {
                                selectedEntry = .gas
                                navigate = true
                            }
                            Button("Ver-/Entsorgung") {
                                selectedEntry = .service
                                navigate = true
                            }
                            Button("Sonstiges") {
                                selectedEntry = .sonstiges
                                navigate = true
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                // Der versteckte NavigationLink löst die Navigation aus, wenn "navigate" true wird.
                .background(
                    NavigationLink(
                        destination: destinationView(for: selectedEntry),
                        isActive: $navigate,
                        label: { EmptyView() }
                    )
                )
        }
    }
    
    @ViewBuilder
    private func destinationView(for entry: EntryType) -> some View {
        switch entry {
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
}

struct EntryView_Previews: PreviewProvider {
    static var previews: some View {
        EntryView()
    }
}
