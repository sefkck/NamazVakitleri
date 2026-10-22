import SwiftUI

/// Alt menüde 5. sekme olarak duran, iOS'un otomatik ürettiği (ve adı
/// özelleştirilemeyen) sistem "More" sekmesi yerine kendi kurduğumuz
/// "Daha Fazla" ekranı. Bu sayede hem sekme adını tam istediğimiz gibi
/// Türkçe tutabiliyoruz hem de Ayarlar'ı da buraya ekleyebiliyoruz.
struct MoreMenuView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var activeSheet: Destination?
    #if DEBUG
    @State private var showLockWidgetsPreview = false
    #endif

    private enum Destination: Identifiable {
        case tracking, imsakiye, diniGunler, duas, esma, hadith, mosques, settings
        var id: Self { self }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background(colorScheme).ignoresSafeArea()

                List {
                    Section {
                        row(title: loc.t("tracking_title", fallback: "Namaz Takibi"), icon: "checkmark.circle") { activeSheet = .tracking }
                        row(title: loc.t("imsakiye_title", fallback: "İmsakiye"), icon: "moon.haze.fill") { activeSheet = .imsakiye }
                        row(title: loc.t("more_religious_days", fallback: "Dini Günler"), icon: "calendar") { activeSheet = .diniGunler }
                        row(title: loc.t("more_duas", fallback: "Namaz Duaları"), icon: "hands.sparkles.fill") { activeSheet = .duas }
                        row(title: loc.t("esma_title", fallback: "Esmâ-i Hüsnâ"), icon: "sparkles") { activeSheet = .esma }
                        row(title: loc.t("hadith_title", fallback: "Günün Hadisi"), icon: "text.book.closed.fill") { activeSheet = .hadith }
                        row(title: loc.t("more_mosques", fallback: "Yakındaki Camiler"), icon: "building.columns.fill") { activeSheet = .mosques }
                    }

                    Section {
                        row(title: loc.t("common_settings", fallback: "Ayarlar"), icon: "gearshape.fill") { activeSheet = .settings }
                    }
                }
                .scrollContentBackground(.hidden)
                // Alttaki menü çubuğu + reklam son satırı örtmesin (büyük yazıda "Ayarlar" altında kalıyordu).
                .contentMargins(.bottom, 130, for: .scrollContent)
            }
            .navigationTitle(loc.t("tab_more", fallback: "Daha Fazla"))
        }
        #if DEBUG
        // Ekran testleri için: -uiTab more -uiSheet tracking
        .onAppear {
            switch UserDefaults.standard.string(forKey: "uiSheet") {
            case "tracking": activeSheet = .tracking
            case "imsakiye": activeSheet = .imsakiye
            case "duas": activeSheet = .duas
            case "esma": activeSheet = .esma
            case "hadith": activeSheet = .hadith
            case "settings": activeSheet = .settings
            case "mosques": activeSheet = .mosques
            case "lockWidgets": showLockWidgetsPreview = true
            default: break
            }
        }
        .fullScreenCover(isPresented: $showLockWidgetsPreview) { LockScreenWidgetsPreview() }
        #endif
        .onAppear {
            // Dil yönü değişince ekran yeniden kuruldu: Ayarlar'a geri dön.
            if LocalizationManager.reopenSettingsAfterRebuild {
                LocalizationManager.reopenSettingsAfterRebuild = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { activeSheet = .settings }
            }
        }
        .sheet(item: $activeSheet) { destination in
            Group {
                switch destination {
                case .tracking: PrayerTrackingView()
                case .imsakiye: ImsakiyeView()
                case .diniGunler: DiniGunlerView()
                case .duas: PrayerDuasView()
                case .esma: EsmaulHusnaView()
                case .hadith: DailyHadithView()
                case .mosques: NearbyMosquesView()
                case .settings: SettingsView()
                }
            }
            // Açılan pencereler kök görünümün yazı yönünü almıyordu: Arapça'da
            // Ayarlar, Namaz Takibi, Dini Günler, İmsakiye ve Camiler soldan sağa kalıyordu.
            .environment(\.layoutDirection, loc.language.isRightToLeft ? .rightToLeft : .leftToRight)
        }
    }

    private func row(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: icon)
                    .foregroundColor(AppTheme.textPrimary(colorScheme))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundColor(AppTheme.textTertiary(colorScheme))
            }
        }
        .listRowBackground(AppTheme.cardFill(colorScheme))
    }
}

#Preview {
    MoreMenuView()
}
