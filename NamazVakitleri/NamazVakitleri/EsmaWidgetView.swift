import SwiftUI

/// "Günün Esmâ'sı" widget görünümü. Widget hedefinde ve (DEBUG ekran
/// testinde) uygulamada derlenir.
struct EsmaWidgetView: View {
    @Environment(\.colorScheme) private var colorScheme
    let name: EsmaulHusna.Name
    let language: AppLanguage
    let medium: Bool

    var body: some View {
        if language == .arabic {
            // Arapçada okunuş ve anlam yok: isim ortada büyük, altında küçük not.
            VStack(spacing: medium ? 6 : 4) {
                header
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
                arabic(size: medium ? 46 : 36)
                Text("من أسماء الله الحسنى")
                    .font(.system(size: medium ? 12 : 10.5))
                    .foregroundStyle(AppTheme.textSecondary(colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .padding(medium ? 14 : 12)
        } else if medium {
            VStack(alignment: .leading, spacing: 6) {
                header
                HStack(spacing: 12) {
                    arabic(size: 40)
                        .frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 4) {
                        texts(nameSize: 18)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: .infinity)
            }
            .padding(14)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                header
                arabic(size: 30)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer(minLength: 0)
                texts(nameSize: 14)
            }
            .padding(12)
        }
    }

    private var header: some View {
        Label(LocalizationManager.translate("widget_esma_name", language: language, fallback: "Günün İsmi"), systemImage: "sparkles")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(AppTheme.gold)
            .lineLimit(1)
    }

    private func arabic(size: CGFloat) -> some View {
        Text(name.arabic)
            .font(.system(size: size))
            .foregroundStyle(AppTheme.accent)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .environment(\.layoutDirection, .rightToLeft)
    }

    @ViewBuilder
    private func texts(nameSize: CGFloat) -> some View {
        if language != .arabic {
            Text(name.displayName(in: language))
                .font(.system(size: nameSize, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary(colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        if let meaning = name.meaning(in: language) {
            Text(meaning)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textSecondary(colorScheme))
                .lineLimit(medium ? 3 : 2)
                .minimumScaleFactor(0.85)
        }
    }
}
