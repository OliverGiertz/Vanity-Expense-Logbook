import SwiftUI

enum EntryType: String, CaseIterable, Identifiable {
    case tanken = "Tanken"
    case gas = "Gas"
    case service = "Ver- / Entsorgung"
    case sonstiges = "Sonstiges"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .tanken:
            return "fuelpump"
        case .gas:
            return "flame"
        case .service:
            return "wrench.and.screwdriver"
        case .sonstiges:
            return "ellipsis.circle"
        }
    }
    
    var description: String {
        switch self {
        case .tanken:
            return "Kraftstoff hinzufügen"
        case .gas:
            return "Gas-Befüllung erfassen"
        case .service:
            return "Ver- oder Entsorgung"
        case .sonstiges:
            return "Andere Kosten"
        }
    }
    
    var color: Color {
        switch self {
        case .tanken:
            return .blue
        case .gas:
            return .orange
        case .service:
            return .green
        case .sonstiges:
            return .purple
        }
    }
}

struct EntryView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Neuen Eintrag erstellen")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.top)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(EntryType.allCases) { entryType in
                            NavigationLink(destination: destinationView(for: entryType)) {
                                EntryTypeCard(entryType: entryType)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationTitle("Eintrag")
            .navigationBarTitleDisplayMode(.large)
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

struct EntryTypeCard: View {
    let entryType: EntryType
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: entryType.icon)
                .font(.system(size: 32))
                .foregroundColor(entryType.color)
            
            Text(entryType.rawValue)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(entryType.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(entryType.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct EntryView_Previews: PreviewProvider {
    static var previews: some View {
        EntryView()
    }
}
