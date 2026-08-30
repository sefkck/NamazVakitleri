import SwiftUI
import Combine
import CoreLocation
import Adhan

struct ContentView: View {
    @EnvironmentObject private var userStore: UserStore
    @StateObject private var locationManager = LocationManager()
    @StateObject private var prayerViewModel = PrayerTimeViewModel()

    @AppStorage("isDarkTheme") private var isDarkTheme: Bool = true

    @AppStorage("useManualLocation") private var useManualLocation: Bool = false
    @AppStorage("manualProvinceName") private var manualProvinceName: String = ""
    @AppStorage("manualLatitude") private var manualLatitude: Double = 0
    @AppStorage("manualLongitude") private var manualLongitude: Double = 0

    @State private var showZikirmatik = false
    @State private var showDiniGunler = false
    @State private var showPrayerDuas = false
    @State private var showQuran = false
    @State private var showQibla = false
    @State private var showMosques = false
    @State private var showSettings = false
    @State private var showProfile = false
    @State private var currentTimeText = "--:--:--"

    private let clockTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let turkeyTimeZone = TimeZone(identifier: "Europe/Istanbul") ?? .current

    private var isPro: Bool { userStore.currentUser?.isPro == true }

    private var backgroundColor: Color {
        isDarkTheme ? .black : Color(.systemBackground)
    }

    private var primaryTextColor: Color {
        isDarkTheme ? .white : .primary
    }

    private var secondaryTextColor: Color {
        isDarkTheme ? .white.opacity(0.7) : .secondary
    }

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

    private var orderedPrayers: [(name: String, date: Date)] {
        guard let times = prayerViewModel.prayerTimes else { return [] }
        return [
            ("İmsak", times.fajr),
            ("Güneş", times.sunrise),
            ("Öğle", times.dhuhr),
            ("İkindi", times.asr),
            ("Akşam", times.maghrib),
            ("Yatsı", times.isha)
        ]
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text(effectiveCityName)
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.light)
                        .foregroundColor(primaryTextColor)

                    Spacer()

                    Button {
                        showProfile = true
                    } label: {
                        profileIcon
                    }

                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundColor(secondaryTextColor)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                if !useManualLocation, let errorMessage = locationManager.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }

                Spacer()

                Text(currentTimeText)
                    .font(.system(size: 52, weight: .thin, design: .rounded))
                    .foregroundColor(primaryTextColor)
                    .monospacedDigit()

                Spacer().frame(height: 24)

                if !orderedPrayers.isEmpty {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        ForEach(orderedPrayers, id: \.name) { prayer in
                            prayerCell(
                                name: prayer.name,
                                date: prayer.date,
                                isNext: prayer.name == prayerViewModel.nextPrayerName
                            )
                        }
                    }
                    .padding(.horizontal, 32)
                } else {
                    ProgressView("Namaz vakitleri hesaplanıyor...")
                        .tint(primaryTextColor)
                        .foregroundColor(primaryTextColor)
                }

                Spacer()

                if !isPro {
                    AdPlaceholderView(label: "Reklam Banner Alanı", height: 44)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)
                }

                // Alt: 3 sütun x 2 satır özellik grid'i
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    islandButton(title: "Zikirmatik", systemImage: "circle.hexagongrid.fill") {
                        showZikirmatik = true
                    }
                    islandButton(title: "Dini Günler", systemImage: "calendar.badge.clock") {
                        showDiniGunler = true
                    }
                    islandButton(title: "Namaz Duaları", systemImage: "hands.sparkles.fill") {
                        showPrayerDuas = true
                    }
                    islandButton(title: "Kuran-ı Kerim", systemImage: "book.closed.fill") {
                        showQuran = true
                    }
                    islandButton(title: "Kıble Bul", systemImage: "location.north.line.fill") {
                        showQibla = true
                    }
                    islandButton(title: "Yakındaki Camiler", systemImage: "building.columns.fill") {
                        showMosques = true
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .preferredColorScheme(isDarkTheme ? .dark : .light)
        .sheet(isPresented: $showZikirmatik) { ZikirmatikView() }
        .sheet(isPresented: $showDiniGunler) { DiniGunlerView() }
        .sheet(isPresented: $showPrayerDuas) { PrayerDuasView() }
        .sheet(isPresented: $showQuran) { QuranView() }
        .sheet(isPresented: $showQibla) {
            QiblaView(manualCoordinate: useManualLocation ? effectiveCoordinate : nil)
        }
        .sheet(isPresented: $showMosques) {
            NearbyMosquesView(manualCoordinate: useManualLocation ? effectiveCoordinate : nil)
        }
        .sheet(isPresented: $showSettings) { SettingsView(isDarkTheme: $isDarkTheme) }
        .sheet(isPresented: $showProfile) { ProfileView() }
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

    @ViewBuilder
    private var profileIcon: some View {
        if let data = userStore.currentUser?.profileImageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 28, height: 28)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.circle")
                .foregroundColor(secondaryTextColor)
        }
    }

    private func refreshWithCurrentSource() {
        guard let coordinate = effectiveCoordinate else { return }
        prayerViewModel.start(coordinate: coordinate, timeZone: effectiveTimeZone)
        updateClock()
    }

    @ViewBuilder
    private func prayerCell(name: String, date: Date, isNext: Bool) -> some View {
        VStack(spacing: 6) {
            Text(name)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(isNext ? .bold : .light)
            Text(formattedTime(date))
                .font(.system(.title3, design: .rounded))
                .fontWeight(isNext ? .bold : .light)
                .monospacedDigit()
        }
        .foregroundColor(isNext ? .orange : primaryTextColor)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isNext ? Color.orange.opacity(0.15) : Color.gray.opacity(isDarkTheme ? 0.18 : 0.1))
        )
    }

    @ViewBuilder
    private func islandButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.title3)
                Text(title)
                    .font(.system(size: 11))
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.orange))
            .foregroundColor(.white)
        }
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
    ContentView().environmentObject(UserStore())
}
