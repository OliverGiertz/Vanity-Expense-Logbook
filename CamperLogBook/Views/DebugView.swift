//
//  DebugView.swift
//  CamperLogBook
//
//  Created by Oliver Giertz on 11.02.25.
//


import SwiftUI

struct DebugView: View {
    var body: some View {
        VStack(spacing: 16) {
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
            Text("Testdaten wurden gelöscht (siehe Konsole)!")
                .font(.footnote)
                .foregroundColor(.gray)
        }
        .padding()
        .navigationTitle("Debug")
    }
}

struct DebugView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DebugView()
        }
    }
}
