import SwiftUI

/// Uygulama teması. Kullanıcı Ayarlar ekranından Aydınlık/Karanlık
/// arasında manuel seçim yapar (RootView bunu .preferredColorScheme
/// ile tüm uygulamaya uygular, sistem ayarını takip etmez).
enum AppTheme {
    /// Karanlık temada yazı ve ikonlar için kullanılan, saf beyaz yerine
    /// hafif sıcak "süt beyazı" ton.
    static let milkWhite = Color(red: 0.97, green: 0.96, blue: 0.93)

    static func background(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.06, green: 0.06, blue: 0.07)
            : Color(red: 0.98, green: 0.965, blue: 0.945)
    }

    static func cardFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.85)
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
        scheme == .dark ? milkWhite : Color(red: 0.20, green: 0.14, blue: 0.15)
    }

    static func textSecondary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? milkWhite.opacity(0.68) : Color(red: 0.45, green: 0.36, blue: 0.37)
    }

    static func textTertiary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? milkWhite.opacity(0.48) : Color(red: 0.62, green: 0.54, blue: 0.54)
    }

    // MARK: - Tipografi

    static func title(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: scaled(size), weight: weight, design: .rounded)
    }

    static func body(_ size: CGFloat = 15, weight: Font.Weight = .regular) -> Font {
        .system(size: scaled(size), weight: weight, design: .rounded)
    }

    /// iPhone Ayarlar > Ekran > Metin Boyutu'na göre yazıyı büyütür/küçültür.
    /// Büyük yazılar (saat, sayaç) ekrana sığsın diye en fazla 1,25 kat,
    /// normal yazılar en fazla 1,6 kat büyür.
    static func scaled(_ size: CGFloat) -> CGFloat {
        let value = UIFontMetrics(forTextStyle: .body).scaledValue(for: size)
        let maxFactor: CGFloat = size >= 28 ? 1.25 : 1.6
        return min(value, size * maxFactor)
    }

    // MARK: - Ölçüler

    static let cardCornerRadius: CGFloat = 20
    static let panelCornerRadius: CGFloat = 28
}
