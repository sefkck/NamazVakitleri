import SwiftUI

/// Ana gezinme yapısı. İlk 5 sekme alt barda görünür (Ana Sayfa,
/// Zikirmatik, Kıble Bul, Kuran, Dini Günler); Namaz Duaları ve
/// Yakındaki Camiler 6. ve 7. sırada oldukları için iOS bunları
/// otomatik olarak "More" sekmesine toplar. Tema, telefonun kendi
/// Açık/Koyu ayarına göre otomatik değişir (zorlama yok).
struct MainTabView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                HomeView()
                    .tabItem {
                        Label("Ana Sayfa", systemImage: "house.fill")
                    }

                ZikirmatikView()
                    .tabItem {
                        Label("Zikirmatik", systemImage: "link")
                    }

                QiblaView()
                    .tabItem {
                        Label("Kıble Bul", systemImage: "safari")
                    }

                QuranView()
                    .tabItem {
                        Label("Kuran", systemImage: "book.fill")
                    }

                DiniGunlerView()
                    .tabItem {
                        Label("Dini Günler", systemImage: "calendar")
                    }

                PrayerDuasView()
                    .tabItem {
                        Label("Namaz Duaları", systemImage: "hands.sparkles.fill")
                    }

                NearbyMosquesView()
                    .tabItem {
                        Label("Yakındaki Camiler", systemImage: "building.columns.fill")
                    }
            }
            .tint(AppTheme.accent)

            // Tüm sekmelerin üstünde sabit reklam paneli
            AdBannerView()
                .frame(height: 50)
                .frame(maxWidth: .infinity)
                .background(AppTheme.background(colorScheme))
        }
        .background(AppTheme.background(colorScheme).ignoresSafeArea(edges: .bottom))
    }
}

#Preview {
    MainTabView()
}
