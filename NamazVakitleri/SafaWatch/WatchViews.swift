import SwiftUI
import WatchKit
import CoreLocation

private let accent = Color(red: 0.70, green: 0.36, blue: 0.40)
private let gold = Color(red: 0.80, green: 0.62, blue: 0.36)

struct WatchRootView: View {
    @ObservedObject private var store = WatchStore.shared
    @ObservedObject private var loc = LocalizationManager.shared
    // Ekran testi: -watchPage 1 (kıble) / 2 (zikirmatik)
    @State private var page = UserDefaults.standard.integer(forKey: "watchPage")

    var body: some View {
        TabView(selection: $page) {
            WatchPrayerPage().tag(0)
            WatchQiblaPage().tag(1)
            WatchZikirPage().tag(2)
        }
        .tabViewStyle(.verticalPage)
        .id(store.revision)
    }
}

// MARK: - Vakitler

struct WatchPrayerPage: View {
    @ObservedObject private var store = WatchStore.shared
    @ObservedObject private var loc = LocalizationManager.shared

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if let (coord, tz) = store.location,
               let days = Optional(PrayerCalculation.upcomingDays(2, coordinate: coord, timeZone: tz, from: context.date)),
               let today = days.first {
                let next = days.flatMap(\.times).first { $0.time > context.date }
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(store.cityName)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        if let next {
                            Text(loc.t("home_next_prayer", fallback: "Sıradaki Namaz"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(loc.x(next.name))
                                .font(.title3.bold())
                                .foregroundStyle(accent)
                            Text(next.time, style: .timer)
                                .font(.system(.title2, design: .rounded).monospacedDigit().bold())
                        }
                        if let k = KerahatTimes.current(now: context.date, coordinate: coord, timeZone: tz) {
                            Label(loc.t(k.kind.localizationKey, fallback: k.kind.turkishName), systemImage: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(gold)
                                .lineLimit(2)
                        }
                        Divider()
                        ForEach(today.times, id: \.name) { item in
                            HStack {
                                Text(loc.x(item.name))
                                    .fontWeight(item.name == next?.name && Calendar.current.isDate(item.time, inSameDayAs: next?.time ?? .distantPast) ? .bold : .regular)
                                Spacer()
                                Text(DisplayFormat.time(item.time, timeZone: tz, locale: loc.locale, compact: true))
                                    .monospacedDigit()
                            }
                            .font(.footnote)
                            .foregroundStyle(item.time < context.date ? .secondary : .primary)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "iphone.gen3")
                        .font(.title2)
                        .foregroundStyle(accent)
                    Text(loc.t("watch_open_phone", fallback: "Konumu almak için iPhone'da uygulamayı bir kez aç."))
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
}

// MARK: - Kıble

struct WatchQiblaPage: View {
    @ObservedObject private var store = WatchStore.shared
    @ObservedObject private var loc = LocalizationManager.shared

    var body: some View {
        VStack(spacing: 6) {
            Text(loc.t("tab_qibla", fallback: "Kıble Bul"))
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let (coord, _) = store.location {
                let bearing = WatchQibla.bearing(from: coord)
                ZStack {
                    Circle().stroke(.secondary.opacity(0.4), lineWidth: 2)
                    Text("N").font(.caption2.bold()).offset(y: -52)
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(accent)
                        .rotationEffect(.degrees(bearing))
                }
                .frame(width: 120, height: 120)
                .environment(\.layoutDirection, .leftToRight)
                Text("\(Int(bearing.rounded()))°")
                    .font(.title3.bold())
                Text(loc.t("watch_qibla_hint", fallback: "Kuzeyden saat yönünde"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text(loc.t("watch_open_phone", fallback: "Konumu almak için iPhone'da uygulamayı bir kez aç."))
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

enum WatchQibla {
    static func bearing(from c: CLLocationCoordinate2D) -> Double {
        let lat1 = c.latitude * .pi / 180, lon1 = c.longitude * .pi / 180
        let lat2 = 21.4225 * .pi / 180, lon2 = 39.8262 * .pi / 180
        let y = sin(lon2 - lon1)
        let x = cos(lat1) * tan(lat2) - sin(lat1) * cos(lon2 - lon1)
        let deg = atan2(y, x) * 180 / .pi
        return (deg + 360).truncatingRemainder(dividingBy: 360)
    }
}

// MARK: - Zikirmatik

struct WatchZikirPage: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @AppStorage("watch_zikir_count") private var count = 0
    @AppStorage("watch_zikir_target") private var target = 33
    @State private var askReset = false

    var body: some View {
        VStack(spacing: 6) {
            Text("\(count) / \(target)")
                .font(.system(.title2, design: .rounded).monospacedDigit().bold())
            Button {
                count += 1
                if count % target == 0 {
                    WKInterfaceDevice.current().play(.success)
                } else {
                    WKInterfaceDevice.current().play(.click)
                }
            } label: {
                Text(loc.t("zikir_tap", fallback: "Çek"))
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, minHeight: 64)
            }
            .tint(accent)
            .buttonStyle(.borderedProminent)
            HStack {
                Button("33") { target = 33 }.tint(target == 33 ? accent : .gray)
                Button("99") { target = 99 }.tint(target == 99 ? accent : .gray)
                Button {
                    askReset = true
                } label: { Image(systemName: "arrow.counterclockwise") }
            }
            .font(.footnote)
        }
        .confirmationDialog(loc.t("zikir_reset_confirm_title", fallback: "Sayaç sıfırlansın mı?"), isPresented: $askReset) {
            Button(loc.t("zikir_reset", fallback: "Sıfırla"), role: .destructive) { count = 0 }
        }
    }
}
