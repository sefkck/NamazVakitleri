import SwiftUI
import WidgetKit

// Kilit ekranı widget'larının görünümü. Bu dosya hem widget hedefinde
// hem uygulamada derlenir: uygulama tarafı sadece DEBUG'da, ekran
// testinde (-uiSheet lockWidgets) görünümü göstermek için kullanır.
// Kilit ekranında renk yoktur; iOS her şeyi tek renk (beyaz/şeffaf) çizer.

enum LockScreenPrayerIcon {
    static func name(for prayer: String) -> String {
        if prayer.contains("İmsak") { return "moon.stars.fill" }
        if prayer.contains("Güneş") { return "sunrise.fill" }
        if prayer.contains("Öğle") { return "sun.max.fill" }
        if prayer.contains("İkindi") { return "sun.haze.fill" }
        if prayer.contains("Akşam") { return "sunset.fill" }
        if prayer.contains("Yatsı") { return "moon.fill" }
        return "clock.fill"
    }
}

/// Saatin üstündeki tek satır: "☀ İkindi 15:51".
struct LockInlinePrayerView: View {
    let prayerName: String
    let prayerDate: Date?
    let timeZone: TimeZone

    var body: some View {
        if let prayerDate {
            Label {
                Text("\(LocalizationManager.xShared(prayerName)) \(Self.timeText(prayerDate, timeZone))")
            } icon: {
                Image(systemName: LockScreenPrayerIcon.name(for: prayerName))
            }
        } else {
            Text(LocalizationManager.tShared("widget_open_app", fallback: "Uygulamayı Açın"))
        }
    }

    static func timeText(_ date: Date, _ timeZone: TimeZone) -> String {
        // Kilit ekranında yer dar: 12 saatte AM/PM yazılmaz.
        DisplayFormat.time(date, timeZone: timeZone, compact: true)
    }
}

/// Yuvarlak: simge + vakit saati.
struct LockCircularPrayerView: View {
    let prayerName: String
    let prayerDate: Date?
    let timeZone: TimeZone

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: LockScreenPrayerIcon.name(for: prayerName))
                    .font(.system(size: 15, weight: .semibold))
                if let prayerDate {
                    Text(LockInlinePrayerView.timeText(prayerDate, timeZone))
                        .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                        .minimumScaleFactor(0.7)
                } else {
                    Text("--:--")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
            }
            .padding(4)
        }
        .widgetAccentable()
    }
}

/// Dikdörtgen: "Sıradaki · İkindi", geri sayım, saat ve şehir.
struct LockRectangularPrayerView: View {
    let prayerName: String
    let prayerDate: Date?
    let timeZone: TimeZone
    let cityName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Image(systemName: LockScreenPrayerIcon.name(for: prayerName))
                Text(LocalizationManager.xShared(prayerName))
                    .fontWeight(.bold)
                if let prayerDate {
                    Text(LockInlinePrayerView.timeText(prayerDate, timeZone))
                        .foregroundStyle(.secondary)
                }
            }
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .widgetAccentable()
            .lineLimit(1)

            if let prayerDate {
                Text(prayerDate, style: .timer)
                    .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                Text(LocalizationManager.tShared("widget_open_app", fallback: "Uygulamayı Açın"))
                    .font(.system(size: 14, weight: .semibold))
            }

            Text(cityName)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if DEBUG
/// Ekran testi: kilit ekranı widget'larını koyu bir zemin üzerinde gösterir.
struct LockScreenWidgetsPreview: View {
    private let date = Date().addingTimeInterval(41 * 60 + 20)

    var body: some View {
        ZStack {
            LinearGradient(colors: [.indigo, .black], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 28) {
                LockInlinePrayerView(prayerName: "İkindi", prayerDate: date, timeZone: .current)
                    .font(.system(size: 15, weight: .semibold))
                Text("09:41").font(.system(size: 90, weight: .bold, design: .rounded))
                HStack(spacing: 16) {
                    LockCircularPrayerView(prayerName: "İkindi", prayerDate: date, timeZone: .current)
                        .frame(width: 72, height: 72)
                    LockRectangularPrayerView(prayerName: "İkindi", prayerDate: date, timeZone: .current, cityName: "İstanbul Fatih")
                        .frame(width: 170, height: 72)
                }
            }
            .foregroundStyle(.white)
        }
    }
}
#endif
