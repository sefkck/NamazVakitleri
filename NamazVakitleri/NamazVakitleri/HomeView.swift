import SwiftUI
import Combine
import CoreLocation
import Adhan

struct HomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var locationManager = LocationManager()
    @StateObject private var prayerViewModel = PrayerTimeViewModel()

    @AppStorage("useManualLocation") private var useManualLocation: Bool = false
    @AppStorage("manualProvinceName") private var manualProvinceName: String = ""
    @AppStorage("manualLatitude") private var manualLatitude: Double = 0
    @AppStorage("manualLongitude") private var manualLongitude: Double = 0

    @State private var showSettings = false
    @State private var currentTimeText = "--:--:--"

    private let clockTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let turkeyTimeZone = TimeZone(identifier: "Europe/Istanbul") ?? .current

    private var effectiveCityName: String {
        useManualLocation
            ? (manualProvinceName.isEmpty ? "İl seçilmedi" : manualProvinceName)
            : locationManager.cityName
    }

    private var effectiveTimeZone: TimeZone {
        useManualLocation ? turkeyTimeZone : locationManager.timeZone
    }

    private var effectiveCoordinate: CLLocationCoordinate2D? {
        if useManualLocation {
            guard !manualProvinceName.isEmpty else { return nil }
            return CLLocationCoordinate2D(latitude: manualLatitude, longitude: manualLongitude)
        }
        return locationManager.coordinate
    }

    private var orderedPrayers: [(name: String, icon: String, date: Date)] {
        guard let times = prayerViewModel.prayerTimes else { return [] }
        return [
            ("İmsak", "moon.stars.fill", times.fajr),
            ("Güneş", "sunrise.fill", times.sunrise),
            ("Öğle", "sun.max.fill", times.dhuhr),
            ("İkindi", "sun.haze.fill", times.asr),
            ("Akşam", "sunset.fill", times.maghrib),
            ("Yatsı", "moon.fill", times.isha)
        ]
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 4..<11: return "Hayırlı Sabahlar"
        case 11..<16: return "Hayırlı Günler"
        case 16..<19: return "Hayırlı Akşamlar"
        default: return "Hayırlı Geceler"
        }
    }

    private var gregorianDateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "d MMMM yyyy, EEEE"
        return formatter.string(from: Date())
    }

    private var hijriDateText: String {
        var calendar = Calendar(identifier: .islamicUmmAlQura)
        calendar.locale = Locale(identifier: "tr_TR")
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: Date())
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    topBar

                    VStack(alignment: .leading, spacing: 4) {
                        Text(greeting)
                            .font(AppTheme.title(30))
                            .foregroundColor(AppTheme.textPrimary(colorScheme))
                        Text("Rabbim, tüm dualarımızı kabul eylesin.")
                            .font(AppTheme.body(14))
                            .foregroundColor(AppTheme.textSecondary(colorScheme))
                    }
                    .padding(.horizontal, 20)

                    HStack {
                        Spacer()
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(AppTheme.accent)
                        Spacer()
                    }
                    .padding(.vertical, 8)

                    if !useManualLocation, let errorMessage = locationManager.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 20)
                    }

                    dateAndCountdownCard
                        .padding(.horizontal, 20)

                    prayerListCard
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                }
                .padding(.top, 8)
            }
            .background(AppTheme.background(colorScheme).ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .onAppear {
            if useManualLocation {
                refreshWithCurrentSource()
            } else {
                locationManager.requestPermission()
            }
        }
        .onReceive(locationManager.$coordinate) { _ in
            guard !useManualLocation else { return }
            refreshWithCurrentSource()
        }
        .onReceive(clockTimer) { _ in
            updateClock()
        }
        .onChange(of: useManualLocation) { _, newValue in
            if newValue {
                refreshWithCurrentSource()
            } else {
                locationManager.requestPermission()
            }
        }
        .onChange(of: manualLatitude) { _, _ in
            if useManualLocation { refreshWithCurrentSource() }
        }
        .onChange(of: manualLongitude) { _, _ in
            if useManualLocation { refreshWithCurrentSource() }
        }
    }

    // MARK: - Alt bileşenler

    private var topBar: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(AppTheme.accent)
                Text(effectiveCityName)
                    .font(AppTheme.body(14, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary(colorScheme))
            }

            Spacer()

            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(AppTheme.textSecondary(colorScheme))
            }
        }
        .padding(.horizontal, 20)
    }

    private var dateAndCountdownCard: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(gregorianDateText)
                    .font(AppTheme.body(12))
                    .foregroundColor(AppTheme.textSecondary(colorScheme))
                Text(currentTimeText)
                    .font(AppTheme.title(28, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary(colorScheme))
                    .monospacedDigit()
                Text("Hicri: \(hijriDateText)")
                    .font(AppTheme.body(11))
                    .foregroundColor(AppTheme.textTertiary(colorScheme))
            }

            Rectangle()
                .fill(AppTheme.cardStroke(colorScheme))
                .frame(width: 1)

            VStack(alignment: .leading, spacing: 6) {
                Text("Sıradaki Namaz")
                    .font(AppTheme.body(12))
                    .foregroundColor(AppTheme.textSecondary(colorScheme))
                Text(prayerViewModel.nextPrayerName)
                    .font(AppTheme.title(20))
                    .foregroundColor(AppTheme.accent)
                Text(prayerViewModel.remainingTimeText)
                    .font(AppTheme.title(18, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary(colorScheme))
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.panelCornerRadius)
                .fill(AppTheme.cardFill(colorScheme))
        )
    }

    private var prayerListCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Namaz Vakitleri")
                .font(AppTheme.body(13, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary(colorScheme))
                .padding(.bottom, 6)

            if orderedPrayers.isEmpty {
                ProgressView("Namaz vakitleri hesaplanıyor...")
                    .tint(AppTheme.accent)
                    .foregroundColor(AppTheme.textSecondary(colorScheme))
                    .padding(.vertical, 12)

                if !useManualLocation && locationManager.isTakingTooLong {
                    VStack(spacing: 10) {
                        Text("Konum alınamıyor. Konum servislerini kontrol et ya da elle il seç.")
                            .font(AppTheme.body(12))
                            .foregroundColor(AppTheme.textSecondary(colorScheme))
                        HStack(spacing: 10) {
                            Button("Tekrar Dene") { locationManager.requestLocation() }
                                .buttonStyle(.borderedProminent)
                                .tint(AppTheme.accent)
                            Button("Ayarlar") { showSettings = true }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            } else {
                ForEach(Array(orderedPrayers.enumerated()), id: \.offset) { index, prayer in
                    prayerRow(prayer: prayer, isNext: prayer.name == prayerViewModel.nextPrayerName)
                    if index < orderedPrayers.count - 1 {
                        Divider().overlay(AppTheme.cardStroke(colorScheme))
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.panelCornerRadius)
                .fill(AppTheme.cardFill(colorScheme))
        )
    }

    private func prayerRow(prayer: (name: String, icon: String, date: Date), isNext: Bool) -> some View {
        HStack {
            Image(systemName: prayer.icon)
                .font(.system(size: 15))
                .foregroundColor(isNext ? AppTheme.accent : AppTheme.gold)
                .frame(width: 20)
            Text(prayer.name)
                .font(AppTheme.body(14, weight: isNext ? .semibold : .regular))
                .foregroundColor(AppTheme.textPrimary(colorScheme))
            Spacer()
            Text(formattedTime(prayer.date))
                .font(AppTheme.body(14, weight: .medium))
                .foregroundColor(AppTheme.textSecondary(colorScheme))
                .monospacedDigit()
            Image(systemName: "bell.fill")
                .font(.caption2)
                .foregroundColor(AppTheme.textTertiary(colorScheme))
        }
        .padding(.vertical, 5)
    }

    // MARK: - Yardımcılar

    private func refreshWithCurrentSource() {
        guard let coordinate = effectiveCoordinate else { return }
        prayerViewModel.start(coordinate: coordinate, timeZone: effectiveTimeZone)
        updateClock()
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = effectiveTimeZone
        return formatter.string(from: date)
    }

    private func updateClock() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.timeZone = effectiveTimeZone
        currentTimeText = formatter.string(from: Date())
    }
}

#Preview {
    HomeView()
}
