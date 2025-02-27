//
//  DebugModeKey.swift
//  CamperLogBook
//
//  Created by Oliver Giertz on 27.02.25.
//


import SwiftUI

// Environment key for debug mode
struct DebugModeKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isDebugMode: Bool {
        get { self[DebugModeKey.self] }
        set { self[DebugModeKey.self] = newValue }
    }
}

// A modifier to conditionally show debug info
struct DebugModifier: ViewModifier {
    @Environment(\.isDebugMode) var isDebugMode
    
    func body(content: Content) -> some View {
        if isDebugMode {
            content
                .overlay(
                    Text("DEBUG MODE")
                        .font(.caption)
                        .padding(4)
                        .background(Color.red.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                        .padding(4),
                    alignment: .topTrailing
                )
        } else {
            content
        }
    }
}

extension View {
    func debugModeIndicator() -> some View {
        self.modifier(DebugModifier())
    }
}