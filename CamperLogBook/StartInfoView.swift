import SwiftUI

struct StartInfoView: View {
    @AppStorage("showStartInfo") var showStartInfo: Bool = true
    @State private var skipFutureStart: Bool = false
    @Environment(\.dismiss) var dismiss

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unbekannt"
    }
    private var releaseDate: String? {
        // Versuche, einen benutzerdefinierten Key "CFBundleReleaseDate" auszulesen
        Bundle.main.infoDictionary?["CFBundleReleaseDate"] as? String
    }
    private var appName: String {
        // Lese den Display Name aus der Info.plist (z. B. "Vanity Expense Logbook")
        Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "Vanity Expense Logbook"
    }
    private var currentYear: String {
        // Das aktuelle Jahr als reine Zahl (z. B. "2025")
        String(Calendar.current.component(.year, from: Date()))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text(appName)
                .font(.largeTitle)
                .bold()
            Text("Version \(appVersion)" + (releaseDate != nil ? " (\(releaseDate!))" : ""))
                .font(.title2)
            // Copyright als Text, z. B. "(c) Vanity on Tour 2025"
            Text("© Vanity on Tour \(currentYear)")
                .font(.footnote)
                .foregroundColor(.gray)
            Spacer()
            Toggle("Beim nächsten Start nicht anzeigen", isOn: $skipFutureStart)
                .padding()
            Button("Weiter") {
                // Wenn der Toggle aktiviert ist, wird showStartInfo deaktiviert, ansonsten bleibt er aktiviert
                showStartInfo = !skipFutureStart
                dismiss()
            }
            .padding()
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

struct StartInfoView_Previews: PreviewProvider {
    static var previews: some View {
        StartInfoView()
    }
}
