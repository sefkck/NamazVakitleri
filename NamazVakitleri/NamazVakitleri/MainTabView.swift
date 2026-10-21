import SwiftUI

/// Ana gezinme yapısı. Tam 5 sekme var: Ana Sayfa, Zikirmatik, Kıble
/// Bul, Kuran ve Daha Fazla. Daha Fazla; Dini Günler, Namaz Duaları,
/// Yakındaki Camiler ve Ayarlar'ı bir liste halinde topluyor - iOS'un
/// adı değiştirilemeyen otomatik "More" sekmesine hiç ihtiyaç kalmıyor.
struct MainTabView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTab: AppTab
    @ObservedObject private var notificationManager = NotificationManager.shared
    @ObservedObject private var loc = LocalizationManager.shared

    init() {
        // Uygulama kapalıyken bir zikir/Kur'an/ayet bildirimine basılırsa,
        // NotificationManager bu View hiç kurulmadan önce requestedTab'ı
        // zaten set etmiş olur (splash ekranının ~2.5 saniyesi buna
        // fazlasıyla yetiyor). Böylece Ana Sayfa hiç görünmeden doğrudan
        // istenen sekmeyle açılıyoruz.
        // Not: burada requestedTab'ı temizlemiyoruz - ekran çizilirken
        // @Published bir değeri değiştirmek SwiftUI'da belirsiz davranışa
        // (yeniden çizim döngüsü / donma) yol açabiliyor. Temizleme
        // aşağıdaki .onReceive içinde zaten yapılıyor (abone olunca mevcut
        // değer hemen iletilir).
        var initialTab = NotificationManager.shared.requestedTab ?? .home
        #if DEBUG
        // Ekran testleri için: -uiTab zikirmatik|qibla|quran|more
        switch UserDefaults.standard.string(forKey: "uiTab") {
        case "zikirmatik": initialTab = .zikirmatik
        case "qibla": initialTab = .qibla
        case "quran": initialTab = .quran
        case "more": initialTab = .more
        default: break
        }
        #endif
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Label(loc.t("tab_home"), systemImage: "house.fill")
                    }
                    .tag(AppTab.home)

                ZikirmatikView()
                    .tabItem {
                        Label(loc.t("tab_zikirmatik"), systemImage: "link")
                    }
                    .tag(AppTab.zikirmatik)

                QiblaView()
                    .tabItem {
                        Label(loc.t("tab_qibla"), systemImage: "safari")
                    }
                    .tag(AppTab.qibla)

                QuranView()
                    .tabItem {
                        Label(loc.t("tab_quran"), systemImage: "book.fill")
                    }
                    .tag(AppTab.quran)

                MoreMenuView()
                    .tabItem {
                        Label(loc.t("tab_more"), systemImage: "ellipsis.circle.fill")
                    }
                    .tag(AppTab.more)
            }
            .tint(AppTheme.accent)

            // Tüm sekmelerin üstünde sabit reklam paneli
            AdBannerView()
                .frame(height: 50)
                .frame(maxWidth: .infinity)
                .background(AppTheme.background(colorScheme))
        }
        .background(AppTheme.background(colorScheme).ignoresSafeArea(edges: .bottom))
        .onReceive(notificationManager.$requestedTab) { tab in
            // Zikir/Kur'an hatırlatıcısına basılınca ilgili sekmeye geç.
            guard let tab else { return }
            selectedTab = tab
            notificationManager.requestedTab = nil
        }
    }
}

#Preview {
    MainTabView()
}
