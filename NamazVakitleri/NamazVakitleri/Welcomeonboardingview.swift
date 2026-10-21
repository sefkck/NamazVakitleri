import SwiftUI

/// Uygulama ilk kez açıldığında, konum/bildirim izni istenmeden ÖNCE
/// gösterilen karşılama ekranı. Arka plan dekoratif şekillerle
/// bulanıklaştırılmış, köşede küçük bir "Safa" avatarı uygulamanın ne
/// işe yaradığını kısaca anlatıp kullanıcıyı izinlere hazırlıyor.
struct WelcomeOnboardingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var loc = LocalizationManager.shared
    let onContinue: () -> Void

    @State private var cardOpacity: Double = 0
    @State private var cardOffset: CGFloat = 20

    /// Dil seçimi: dokununca tüm metinler ANINDA o dile geçer.
    private var languageSelector: some View {
        HStack(spacing: 8) {
            Image(systemName: "globe")
                .font(.system(size: 16))
                .foregroundColor(AppTheme.accent)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AppLanguage.allCases) { lang in
                        let isSelected = loc.language == lang
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                loc.language = lang
                            }
                        } label: {
                            Text(lang.displayName)
                                .font(AppTheme.body(13, weight: .semibold))
                                .lineLimit(1)
                                .fixedSize()
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .foregroundColor(isSelected ? .white : AppTheme.textPrimary(colorScheme))
                                .background(
                                    Capsule().fill(isSelected ? AppTheme.accent : AppTheme.cardFill(colorScheme))
                                )
                                .overlay(
                                    Capsule().stroke(AppTheme.cardStroke(colorScheme), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.trailing, 16)
            }
        }
    }

    var body: some View {
        ZStack {
            // Dekoratif, bulanık arka plan - gerçek uygulama ekranlarını
            // (ve onların izin isteyen mantığını) burada hiç
            // tetiklemiyoruz, sadece "arkada bir şeyler var" hissi.
            AppTheme.background(colorScheme).ignoresSafeArea()

            Circle()
                .fill(AppTheme.accent.opacity(0.35))
                .frame(width: 320, height: 320)
                .offset(x: -120, y: -260)

            Circle()
                .fill(AppTheme.gold.opacity(0.3))
                .frame(width: 280, height: 280)
                .offset(x: 140, y: 200)

            Image(systemName: "moon.stars.fill")
                .font(.system(size: 160))
                .foregroundColor(AppTheme.accent.opacity(0.25))
                .offset(y: -40)

            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                Spacer()

                // Sohbet balonu - avatarın hemen üzerinde.
                VStack(alignment: .leading, spacing: 12) {
                    Text(loc.t("welcome_title"))
                        .font(AppTheme.title(19, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary(colorScheme))

                    Text(loc.t("welcome_body"))
                        .font(AppTheme.body(14))
                        .foregroundColor(AppTheme.textSecondary(colorScheme))
                        .fixedSize(horizontal: false, vertical: true)

                    Button(action: onContinue) {
                        Text(loc.t("common_continue"))
                            .font(AppTheme.body(16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.top, 2)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(AppTheme.cardFill(colorScheme))
                        .shadow(color: .black.opacity(0.2), radius: 16, y: 8)
                )
                .padding(.horizontal, 16)

                // Avatar - sol altta; altında dil seçimi (varsayılan: telefonun dili).
                VStack(alignment: .leading, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.accent, AppTheme.gold],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)

                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.white)
                }
                .shadow(color: .black.opacity(0.25), radius: 8, y: 4)

                    languageSelector
                }
                .padding(.leading, 24)
                .padding(.bottom, 24)
            }
            .opacity(cardOpacity)
            .offset(y: cardOffset)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                cardOpacity = 1
                cardOffset = 0
            }
        }
    }
}

#Preview {
    WelcomeOnboardingView(onContinue: {})
}
