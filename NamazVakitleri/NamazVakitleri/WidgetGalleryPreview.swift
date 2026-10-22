#if DEBUG
import SwiftUI
import WidgetKit

/// Ekran testi: ana ekran widget'larını gerçek boyutlarında, açık ya da koyu
/// temada çizer. Ana ekrana dokunmadan widget tasarımını kontrol etmek için.
/// Kullanım: -uiTab more -uiSheet widgetGallery -uiWidgetTheme dark -uiWidgetPage 1|2
struct WidgetGalleryPreview: View {
    private let scheme: ColorScheme = UserDefaults.standard.string(forKey: "uiWidgetTheme") == "dark" ? .dark : .light
    private let page = max(1, UserDefaults.standard.integer(forKey: "uiWidgetPage"))

    // iPhone 17 Pro ana ekran widget boyutları (pt).
    private let small = CGSize(width: 170, height: 170)
    private let medium = CGSize(width: 364, height: 170)
    private let large = CGSize(width: 364, height: 382)

    private var entry: PrayerEntry {
        if let snapshot = PrayerWidgetData.load(),
           let step = PrayerWidgetData.timelineSteps(from: snapshot).first {
            return PrayerEntry(date: step.date, nextPrayerName: step.nextName, nextPrayerDate: step.nextDate,
                               cityName: snapshot.cityName, dailyTimes: step.today, timeZone: snapshot.timeZone)
        }
        return PrayerEntry(date: Date(), nextPrayerName: "İkindi", nextPrayerDate: Date().addingTimeInterval(3600),
                           cityName: "İstanbul Fatih", dailyTimes: [])
    }

    private func ayah(_ index: Int) -> AyahEntry {
        let list = AyahPool.localizedShared()
        let v = list[index % list.count]
        return AyahEntry(date: Date(), reference: v.reference, text: v.text)
    }

    private func card<V: View>(_ size: CGSize, @ViewBuilder _ content: () -> V) -> some View {
        content()
            .padding(16) // WidgetKit'in varsayılan kenar boşluğu
            .frame(width: size.width, height: size.height)
            .background(WidgetBackdrop(colorScheme: scheme))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .foregroundStyle(AppTheme.textPrimary(scheme))
            .environment(\.colorScheme, scheme)
            .environment(\.layoutDirection, LocalizationManager.sharedLanguage().isRightToLeft ? .rightToLeft : .leftToRight)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if page == 1 {
                    HStack(spacing: 22) {
                        card(small) { SmallPrayerWidgetView(entry: entry) }
                        card(small) { AyahWidgetView(family: .systemSmall, entry: ayah(3)) }
                    }
                    card(medium) { MediumPrayerWidgetView(entry: entry) }
                    card(medium) { DailyPrayerListView(family: .systemMedium, entry: entry) }
                    card(medium) { AyahWidgetView(family: .systemMedium, entry: ayah(0)) }
                } else {
                    card(large) { DailyPrayerListView(family: .systemLarge, entry: entry) }
                    HStack(spacing: 22) {
                        card(small) { EsmaWidgetView(name: EsmaulHusna.nameOfDay(), language: LocalizationManager.sharedLanguage(), medium: false) }
                        card(small) { AyahWidgetView(family: .systemSmall, entry: ayah(0)) }
                    }
                    card(medium) { EsmaWidgetView(name: EsmaulHusna.nameOfDay(), language: LocalizationManager.sharedLanguage(), medium: true) }
                }
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
        .background(
            LinearGradient(colors: scheme == .dark ? [Color(white: 0.12), .black] : [Color(red: 0.62, green: 0.75, blue: 0.86), Color(red: 0.36, green: 0.52, blue: 0.72)],
                           startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        )
    }
}
#endif
