import SwiftUI

struct DebugView: View {
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Aktionen")) {
                    Button(action: {
                        deleteAllTestData()
                    }) {
                        Text("Alle Testdaten löschen")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red)
                            .cornerRadius(8)
                    }
                }
                
                Section(header: Text("Core Data Debug")) {
                    NavigationLink(destination: CoreDataDebugView()) {
                        Text("Core Data Einträge anzeigen")
                    }
                }
            }
            .navigationTitle("Debug")
        }
    }
}

struct DebugView_Previews: PreviewProvider {
    static var previews: some View {
        DebugView()
    }
}
