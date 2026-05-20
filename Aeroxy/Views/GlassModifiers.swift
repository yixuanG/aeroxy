import SwiftUI

extension View {
    @ViewBuilder
    func aeroxyGlass(cornerRadius: CGFloat = 12) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(
                .regular,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        } else {
            self.background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        }
    }
}

struct AeroxyGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .opacity(configuration.isPressed ? 0.72 : 1)
            .aeroxyGlass(cornerRadius: 8)
    }
}

struct AeroxyGlassProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .opacity(configuration.isPressed ? 0.78 : 1)
            .modifier(ProminentGlassBackground())
    }
}

private struct ProminentGlassBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.buttonStyle(.glassProminent)
        } else {
            content
                .foregroundStyle(.white)
                .background(
                    Color.accentColor,
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
        }
    }
}

extension ButtonStyle where Self == AeroxyGlassButtonStyle {
    static var aeroxyGlass: AeroxyGlassButtonStyle {
        AeroxyGlassButtonStyle()
    }
}

extension ButtonStyle where Self == AeroxyGlassProminentButtonStyle {
    static var aeroxyGlassProminent: AeroxyGlassProminentButtonStyle {
        AeroxyGlassProminentButtonStyle()
    }
}

