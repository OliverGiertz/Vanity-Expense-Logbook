import SwiftUI
import UniformTypeIdentifiers

/// View zum Exportieren eines Backup-Verzeichnisses
struct ExportBackupView: View {
    @Environment(\.dismiss) var dismiss
    
    let directoryURL: URL
    @State private var showingOptions = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.and.arrow.up.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Backup exportieren")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Dein Backup ist bereit zum Exportieren. Du kannst es direkt teilen oder in einer anderen App öffnen.")
                .multilineTextAlignment(.center)
                .padding()
            
            Button(action: { showingOptions = true }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Backup teilen")
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.horizontal)
            
            Button(action: { dismiss() }) {
                Text("Abbrechen")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingOptions) {
            ActivityView(activityItems: [directoryURL])
        }
    }
}
