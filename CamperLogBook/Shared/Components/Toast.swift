import SwiftUI

struct ToastView: View {
    let title: String
    let subtitle: String?
    let systemImage: String

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.black.opacity(0.8), in: Capsule())
        .shadow(radius: 8)
        .padding(.horizontal, 16)
    }
}

private struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let subtitle: String?
    let systemImage: String
    let duration: TimeInterval
    let alignment: Alignment

    func body(content: Content) -> some View {
        ZStack(alignment: alignment) {
            content
            if isPresented {
                ToastView(title: title, subtitle: subtitle, systemImage: systemImage)
                    .transition(.move(edge: alignment == .top ? .top : .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                            withAnimation { isPresented = false }
                        }
                    }
                    .padding(.vertical, 20)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: isPresented)
    }
}

extension View {
    func toast(
        isPresented: Binding<Bool>,
        title: String,
        subtitle: String? = nil,
        systemImage: String = "checkmark.circle.fill",
        duration: TimeInterval = 2.2,
        alignment: Alignment = .bottom
    ) -> some View {
        modifier(ToastModifier(
            isPresented: isPresented,
            title: title,
            subtitle: subtitle,
            systemImage: systemImage,
            duration: duration,
            alignment: alignment
        ))
    }
}

