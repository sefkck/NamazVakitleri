import SwiftUI

/// Uygulama teması. Zorlama yok - telefonun Ayarlar > Görünüm
/// tercihine (Açık/Koyu/Sistem) otomatik uyar, çünkü hiçbir yerde
/// .preferredColorScheme() ile üzerine yazılmıyor.
enum AppTheme {
    static func background(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.06, green: 0.06, blue: 0.07)
            : Color(red: 0.97, green: 0.95, blue: 0.92)
    }

    static func cardFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.8)
    }

    static func cardStroke(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.06)
    }

    static let accent = Color(red: 0.70, green: 0.36, blue: 0.40)
    static let gold = Color(red: 0.80, green: 0.62, blue: 0.40)

    static func accentSoft(_ scheme: ColorScheme) -> Color {
        accent.opacity(scheme == .dark ? 0.22 : 0.12)
    }

    static func textPrimary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .white : Color(red: 0.20, green: 0.14, blue: 0.15)
    }

    static func textSecondary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.65) : Color(red: 0.45, green: 0.36, blue: 0.37)
    }

    static func textTertiary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.45) : Color(red: 0.62, green: 0.54, blue: 0.54)
    }

    // MARK: - Tipografi

    static func title(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func body(_ size: CGFloat = 15, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    // MARK: - Ölçüler

    static let cardCornerRadius: CGFloat = 20
    static let panelCornerRadius: CGFloat = 28
}
