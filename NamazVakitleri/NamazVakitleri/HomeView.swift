import SwiftUI
import Combine
import CoreLocation
import Adhan

struct HomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var loc = LocalizationManager.shared
    @StateObject private var locationManager = LocationManager()
    @StateObject private var prayerViewModel = PrayerTimeViewModel()

    @AppStorage("showKerahat") private var showKerahat: Bool = true
    @AppStorage("useManualLocation") private var useManualLocation: Bool = false
    @AppStorage("manualProvinceName") private var manualProvinceName: String = ""
    @AppStorage("manualLatitude") private var manualLatitude: Double = 0
    @AppStorage("manualLongitude") private var manualLongitude: Double = 0
    /// Elle seçilen yerin saat dilimi. İl listesinden seçimde İstanbul,
    /// adres aramasında (yurt dışı olabilir) bulunan yerin saat dilimi.
    @AppStorage("manualTimeZoneID") private var manualTimeZoneID: String = "Europe/Istanbul"

    @State private var showSettings = false
    /// Ana sayfadaki zil düğmeleri: hangi vaktin alarmı açık.
    @State private var alarmEnabled: [String: Bool] = [:]
    /// Bugün "kıldım" olarak işaretlenen vakitler.
    @State private var prayedToday: Set<String> = []
    @State private var showNotificationsDenied = false
    /// Zile dokununca kısa süre görünen "Akşam alarmı açıldı/kapatıldı" yazısı.
    @State private var alarmToast: String?
    @State private var alarmToastID = 0
    @State private var currentTimeText = "--:--:--"

    private let clockTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let turkeyTimeZone = TimeZone(identifier: "Europe/Istanbul") ?? .current

    private var effectiveCityName: String {
        if useManualLocation {
            return manualProvinceName.isEmpty ? loc.t("home_no_city", fallback: "İl seçilmedi") : manualProvinceName
        }
        if isUsingCachedFallback, let cached = UserDefaults.standard.string(forKey: "lastKnownCityName"), !cached.isEmpty {
            return cached
        }
        return locationManager.cityName
    }

    private var effectiveTimeZone: TimeZone {
        if useManualLocation {
            return TimeZone(identifier: manualTimeZoneID) ?? turkeyTimeZone
        }
        if isUsingCachedFallback,
           let cachedID = UserDefaults.standard.string(forKey: "lastKnownTimeZoneID"),
           let cached = TimeZone(identifier: cachedID) {
            return cached
        }
        return locationManager.timeZone
    }

    private var effectiveCoordinate: CLLocationCoordinate2D? {
        if useManualLocation {
            guard !manualProvinceName.isEmpty else { return nil }
            return CLLocationCoordinate2D(latitude: manualLatitude, longitude: manualLongitude)
        }
        if let live = locationManager.coordinate {
            return live
        }
        // GPS/internet şu anda konum veremiyorsa, daha önce kaydedilmiş
        // son bilinen konumu geçici olarak kullan - hiç veri göstermemek
        // yerine (muhtemelen hâlâ doğruya yakın) eski veriyi göstermek
        // daha kullanışlı, kullanıcıya da bunun geçici olduğunu ayrıca
        // belirtiyoruz.
        return cachedFallbackCoordinate
    }

    private var cachedFallbackCoordinate: CLLocationCoordinate2D? {
        let lat = UserDefaults.standard.double(forKey: "lastKnownLatitude")
        let lon = UserDefaults.standard.double(forKey: "lastKnownLongitude")
        guard lat != 0 || lon != 0 else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// Şu an ekranda gösterilen konum, canlı GPS'ten değil önbellekten
    /// geliyorsa true döner - bunu kullanıcıya ayrı bir bilgi notuyla
    /// belirtiyoruz.
    private var isUsingCachedFallback: Bool {
        !useManualLocation && locationManager.coordinate == nil && cachedFallbackCoordinate != nil
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

    /// Selamlama, tarih ve Hicri tarih konumun saat dilimine göredir (telefonunkine
    /// göre değil): yurt dışında ya da başka ülkeden adres seçilince yanlış gün /
    /// "sabah 9'da iyi akşamlar" çıkıyordu.
    private var locationCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = effectiveTimeZone
        return c
    }

    private var greeting: String {
        let hour = locationCalendar.component(.hour, from: DebugClock.now)
        switch hour {
        case 4..<11: return loc.t("home_greet_morning", fallback: "Hayırlı Sabahlar")
        case 11..<16: return loc.t("home_greet_day", fallback: "Hayırlı Günler")
        case 16..<19: return loc.t("home_greet_evening", fallback: "Hayırlı Akşamlar")
        default: return loc.t("home_greet_night", fallback: "Hayırlı Geceler")
        }
    }

    private var gregorianDateText: String {
        let formatter = DateFormatter()
        formatter.locale = loc.locale
        formatter.dateFormat = "d MMMM yyyy, EEEE"
        formatter.timeZone = effectiveTimeZone
        return formatter.string(from: DebugClock.now)
    }

    private var hijriDateText: String {
        var calendar = Calendar(identifier: .islamicUmmAlQura)
        calendar.locale = loc.locale
        calendar.timeZone = effectiveTimeZone
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = loc.locale
        formatter.timeZone = effectiveTimeZone
        formatter.dateFormat = "d"
        let day = formatter.string(from: DebugClock.now)
        formatter.dateFormat = "MMMM yyyy"
        // Ay adı ve yıl bölünmesin (Almanca "Dschumada I 1448" iki satıra
        // bölünüp "I 1448" tek başına kalıyordu): boşluklar bölünmez boşluk.
        let monthYear = formatter.string(from: DebugClock.now).replacingOccurrences(of: " ", with: "\u{00A0}")
        return "\(day) \(monthYear)"
    }

    var body: some View {
        NavigationView {
            // Ekran boyuna göre en büyük sığan düzen seçilir: geniş →
            // sıkı → (sadece çok kısa ekranlarda) kaydırılabilir. Böylece
            // iPhone SE / 13 mini / 13 gibi ekranlarda vakitler sekme
            // çubuğunun arkasında kalmaz.
            GeometryReader { geo in
                ViewThatFits(in: .vertical) {
                    homeContent(.regular)
                    homeContent(.compact)
                    ScrollView { homeContent(.tight) }
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            }
            .background(AppTheme.background(colorScheme).ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .onAppear {
            reloadAlarmStates()
            reloadPrayed()
        }
        .overlay(alignment: .bottom) {
            if let alarmToast {
                Text(alarmToast)
                    .font(AppTheme.body(15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.black.opacity(0.82)))
                    .padding(.bottom, 110)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityAddTraits(.isStaticText)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: PrayerTracker.didChange)) { _ in
            reloadPrayed()
        }
        .onChange(of: todayKey) { _, _ in reloadPrayed() }
        .onReceive(NotificationCenter.default.publisher(for: NotificationManager.prayerPrefsDidChange)) { _ in
            reloadAlarmStates()
        }
        .alert(loc.t("settings_notif_denied", fallback: "Bildirimler kapalı. Namaz alarmları gelmez."), isPresented: $showNotificationsDenied) {
            Button(loc.t("settings_open_ios_settings", fallback: "iPhone Ayarları'nı Aç")) {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button(loc.t("primer_later", fallback: "Şimdi değil"), role: .cancel) {}
        } message: {
            Text(loc.t("home_alarm_denied_body", fallback: "Alarmı açmak için iPhone Ayarları'nda bu uygulamanın bildirimlerine izin ver."))
        }
        .onAppear {
            // Önce elde olanla (elle seçilen ya da son bilinen konum) hemen
            // hesapla ve bildirimleri tazele; GPS sonra gelirse onu kullanır.
            refreshWithCurrentSource()
            if !useManualLocation {
                locationManager.requestPermission()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: PrayerCalculation.adjustmentsDidChange)) { _ in
            refreshWithCurrentSource()
        }
        .onReceive(locationManager.$coordinate) { newCoordinate in
            // DİKKAT: @Published, değeri gerçekten değiştirmeden hemen önce
            // yayınlar (willSet gibi davranır). Bu yüzden burada
            // locationManager.coordinate'i tekrar okumak yerine doğrudan
            // yayınlanan `newCoordinate` değerini kullanıyoruz - aksi halde
            // ilk GPS düzeltmesinde hâlâ eski (nil) değeri görüp namaz
            // vakitlerini hiç hesaplamıyordu.
            guard !useManualLocation, let newCoordinate else { return }
            applyResolvedLocation(coordinate: newCoordinate, timeZone: locationManager.timeZone)
        }
        .onReceive(locationManager.$timeZone) { newTimeZone in
            // Saat dilimi, reverse geocoding tamamlandığında konumdan
            // ayrı/daha sonra çözülür; geldiğinde de yeniden hesapla.
            guard !useManualLocation, let coordinate = locationManager.coordinate else { return }
            applyResolvedLocation(coordinate: coordinate, timeZone: newTimeZone)
        }
        .onReceive(clockTimer) { _ in
            updateClock()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Bildirime dokunup uygulamaya dönünce, arka plandan geri
            // gelince veya kilit açılınca ekran bir şekilde eksik/bozuk
            // kalmasın diye namaz vakitlerini her defasında zorla
            // yeniden hesaplıyoruz.
            guard newPhase == .active else { return }
            refreshWithCurrentSource()
        }
        .onChange(of: useManualLocation) { _, newValue in
            // GPS'e dönüşte de hemen yeniden hesapla: konum 500 m'den az
            // değiştiyse LocationManager yeni bir değer yayınlamıyor.
            refreshWithCurrentSource()
            if !newValue {
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

    // MARK: - Düzen (ekran boyuna göre)

    struct HomeLayout {
        var showMoon: Bool
        var showDua: Bool
        var showBellHint: Bool
        var greetingSize: CGFloat
        var clockSize: CGFloat
        var nextNameSize: CGFloat
        var countdownSize: CGFloat
        var cardPadding: CGFloat
        var rowHeight: CGFloat
        var spacing: CGFloat

        static let regular = HomeLayout(showMoon: true, showDua: true, showBellHint: true, greetingSize: 28,
                                        clockSize: 28, nextNameSize: 20, countdownSize: 18,
                                        cardPadding: 18, rowHeight: 42, spacing: 12)
        static let compact = HomeLayout(showMoon: false, showDua: true, showBellHint: true, greetingSize: 24,
                                        clockSize: 26, nextNameSize: 19, countdownSize: 17,
                                        cardPadding: 14, rowHeight: 38, spacing: 10)
        static let tight = HomeLayout(showMoon: false, showDua: false, showBellHint: false, greetingSize: 22,
                                      clockSize: 24, nextNameSize: 18, countdownSize: 16,
                                      cardPadding: 12, rowHeight: 34, spacing: 8)
    }

    private func homeContent(_ layout: HomeLayout) -> some View {
        VStack(alignment: .leading, spacing: layout.spacing) {
            topBar

            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(AppTheme.title(layout.greetingSize))
                    .foregroundColor(AppTheme.textPrimary(colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if layout.showDua {
                    Text(loc.t("home_dua", fallback: "Rabbim, tüm dualarımızı kabul eylesin."))
                        .font(AppTheme.body(14))
                        .foregroundColor(AppTheme.textSecondary(colorScheme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .padding(.horizontal, 20)

            if layout.showMoon && (useManualLocation || locationManager.errorMessage == nil) {
                HStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(RadialGradient(colors: [AppTheme.gold.opacity(0.28), .clear],
                                                 center: .center, startRadius: 2, endRadius: 30))
                            .frame(width: 60, height: 60)
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(AppTheme.accent)
                    }
                    .accessibilityHidden(true)
                    Spacer()
                }
            }

            if !useManualLocation, let errorMessage = locationManager.errorMessage {
                VStack(alignment: .leading, spacing: 4) {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                    Text(loc.t("home_manual_hint", fallback: "Daha net bilgi almak için Ayarlar'dan manuel konum girebilirsiniz."))
                        .font(.footnote)
                        .foregroundStyle(AppTheme.textSecondary(colorScheme))
                    if isUsingCachedFallback {
                        Text(loc.t("home_cached_notice", fallback: "İnternet ve GPS sistemi açık olmadığı için geçici olarak son bilinen konum kullanılıyor."))
                            .font(.footnote)
                            .foregroundStyle(AppTheme.textSecondary(colorScheme))
                    }
                    Button(loc.t("home_retry")) {
                        locationManager.requestPermission()
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(AppTheme.accent)
                    .padding(.top, 2)
                }
                .padding(.horizontal, 20)
            }

            dateAndCountdownCard(layout)
                .padding(.horizontal, 16)

            prayerListCard(layout)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
        .padding(.top, 6)
    }

    // MARK: - Alt bileşenler

    private var topBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "mappin.circle.fill")
                .foregroundColor(AppTheme.accent)
            Text(effectiveCityName)
                .font(AppTheme.body(14, weight: .medium))
                .foregroundColor(AppTheme.textPrimary(colorScheme))
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    /// Ramazan'da iftar ya da sahur geri sayımı (Ramazan dışında nil).
    private var fastingTarget: RamadanInfo.FastingTarget? {
        guard let coordinate = effectiveCoordinate else { return nil }
        return RamadanInfo.fastingTarget(now: DebugClock.now, coordinate: coordinate, timeZone: effectiveTimeZone)
    }

    private func dateAndCountdownCard(_ layout: HomeLayout) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(gregorianDateText)
                        .font(AppTheme.body(12))
                        .foregroundColor(AppTheme.textSecondary(colorScheme))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(currentTimeText)
                        .font(AppTheme.title(layout.clockSize, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary(colorScheme))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(loc.tf("home_hijri", "Hicri: %@", hijriDateText))
                        .font(AppTheme.body(11))
                        .foregroundColor(AppTheme.textTertiary(colorScheme))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle()
                    .fill(AppTheme.cardStroke(colorScheme))
                    .frame(width: 1)

                VStack(alignment: .leading, spacing: 4) {
                    Text(loc.t("home_next_prayer"))
                        .font(AppTheme.body(12))
                        .foregroundColor(AppTheme.textSecondary(colorScheme))
                        .lineLimit(1)
                    Text(loc.x(prayerViewModel.nextPrayerName))
                        .font(AppTheme.title(layout.nextNameSize))
                        .foregroundColor(AppTheme.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    // Geri sayım saat gibi okunuyordu: yanına "kaldı" yazılır.
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(prayerViewModel.remainingTimeText)
                            .font(AppTheme.title(layout.countdownSize, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary(colorScheme))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(loc.t("home_time_left", fallback: "kaldı"))
                            .font(AppTheme.body(12))
                            .foregroundColor(AppTheme.textSecondary(colorScheme))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .fixedSize(horizontal: false, vertical: true)

            if let target = fastingTarget {
                ramadanStrip(target)
            }
            if showKerahat, let window = currentKerahat {
                kerahatStrip(window)
            }
        }
        .padding(layout.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.panelCornerRadius)
                .fill(AppTheme.cardFill(colorScheme))
        )
    }

    /// Şu an kerahat vaktiyse o vakit (yaklaşık 45 dk; bkz. KerahatTimes).
    private var currentKerahat: KerahatTimes.Window? {
        guard let coordinate = effectiveCoordinate else { return nil }
        return KerahatTimes.current(now: DebugClock.now, coordinate: coordinate, timeZone: effectiveTimeZone)
    }

    private func kerahatStrip(_ window: KerahatTimes.Window) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(AppTheme.gold)
            VStack(alignment: .leading, spacing: 1) {
                Text(loc.t("kerahat_now_title", fallback: "Kerahat vakti (yaklaşık)"))
                    .font(AppTheme.body(13, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary(colorScheme))
                Text(loc.t(window.kind.localizationKey, fallback: window.kind.turkishName))
                    .font(AppTheme.body(11))
                    .foregroundColor(AppTheme.textSecondary(colorScheme))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            countdownText(to: window.end)
                .font(AppTheme.title(15, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(AppTheme.accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.accentSoft(colorScheme)))
        .accessibilityElement(children: .combine)
    }

    /// Canlı geri sayım. Test saatinde (-uiTestDate) sistem sayacı gerçek saati
    /// kullandığı için kalan süre test saatine göre yazılır.
    @ViewBuilder
    private func countdownText(to date: Date) -> some View {
        if DebugClock.isOverridden {
            let t = max(0, Int(date.timeIntervalSince(DebugClock.now)))
            Text(String(format: "%d:%02d:%02d", t / 3600, (t % 3600) / 60, t % 60))
        } else {
            Text(date, style: .timer)
        }
    }

    private func ramadanStrip(_ target: RamadanInfo.FastingTarget) -> some View {
        let (label, date): (String, Date) = {
            switch target {
            case .iftar(let d): return (loc.t("ramadan_to_iftar", fallback: "İftara kalan"), d)
            case .sahur(let d): return (loc.t("ramadan_to_sahur", fallback: "Sahurun bitişine (İmsak) kalan"), d)
            }
        }()
        return HStack(spacing: 8) {
            Image(systemName: "moon.haze.fill")
                .foregroundColor(AppTheme.gold)
            Text(label)
                .font(AppTheme.body(13, weight: .medium))
                .foregroundColor(AppTheme.textPrimary(colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            countdownText(to: date)
                .font(AppTheme.title(15, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(AppTheme.accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.accentSoft(colorScheme)))
        .accessibilityElement(children: .combine)
    }

    private var todayKey: String {
        PrayerTracker.dayKey(prayerViewModel.prayerTimes?.fajr ?? Date(), timeZone: effectiveTimeZone)
    }

    private func prayerListCard(_ layout: HomeLayout) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(loc.t("home_prayer_times_title"))
                    .font(AppTheme.body(13, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary(colorScheme))
                Spacer()
                let count = prayedToday.count
                Label(loc.tf("home_prayed_count", "%d/5 kılındı", count), systemImage: "checkmark.circle")
                    .font(AppTheme.body(11, weight: .medium))
                    .foregroundColor(count == 5 ? AppTheme.accent : AppTheme.textTertiary(colorScheme))
                    .lineLimit(1)
            }
            .padding(.bottom, 4)

            if layout.showBellHint {
                Text(loc.t("home_row_hint", fallback: "○ dokun: kıldım olarak işaretle · 🔔 dokun: alarm aç/kapat"))
                    .font(AppTheme.body(13, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary(colorScheme))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 4)
            }

            if prayerViewModel.calculationFailed {
                Text(loc.t("home_calc_failed", fallback: "Bu konum için namaz vakitleri hesaplanamıyor. Lütfen başka bir konum seç."))
                    .font(AppTheme.body(13))
                    .foregroundColor(AppTheme.textSecondary(colorScheme))
                    .padding(.vertical, 12)
            } else if orderedPrayers.isEmpty {
                ProgressView(loc.t("home_calculating", fallback: "Namaz vakitleri hesaplanıyor..."))
                    .tint(AppTheme.accent)
                    .foregroundColor(AppTheme.textSecondary(colorScheme))
                    .padding(.vertical, 12)

                if !useManualLocation && locationManager.isTakingTooLong {
                    VStack(spacing: 10) {
                        Text(loc.t("home_loc_unavailable", fallback: "Konum alınamıyor. Konum servislerini kontrol et ya da elle il seç."))
                            .font(AppTheme.body(12))
                            .foregroundColor(AppTheme.textSecondary(colorScheme))
                        HStack(spacing: 10) {
                            Button(loc.t("home_retry")) { locationManager.requestLocation() }
                                .buttonStyle(.borderedProminent)
                                .tint(AppTheme.accent)
                            Button(loc.t("common_settings", fallback: "Ayarlar")) { showSettings = true }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            } else {
                ForEach(Array(orderedPrayers.enumerated()), id: \.offset) { index, prayer in
                    prayerRow(prayer: prayer, isNext: prayer.name == prayerViewModel.nextPrayerName, layout: layout)
                    if index < orderedPrayers.count - 1 {
                        Divider().overlay(AppTheme.cardStroke(colorScheme))
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.panelCornerRadius)
                .fill(AppTheme.cardFill(colorScheme))
        )
    }

    private func prayerRow(prayer: (name: String, icon: String, date: Date), isNext: Bool, layout: HomeLayout) -> some View {
        let isPrayer = NotificationManager.prayerNames.contains(prayer.name)
        let hasStarted = prayer.date <= DebugClock.now
        let isPrayed = prayedToday.contains(prayer.name)
        return HStack(spacing: 6) {
            Image(systemName: prayer.icon)
                .font(.system(size: 15))
                .foregroundColor(isNext ? AppTheme.accent : AppTheme.gold)
                .frame(width: 22)
            Text(loc.x(prayer.name))
                .font(AppTheme.body(15, weight: isNext ? .semibold : .regular))
                .foregroundColor(AppTheme.textPrimary(colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            Text(formattedTime(prayer.date))
                .font(AppTheme.body(15, weight: .medium))
                .foregroundColor(AppTheme.textSecondary(colorScheme))
                .monospacedDigit()

            // "Kıldım" işareti: sadece vakti girmiş namazlar için.
            if isPrayer && hasStarted {
                Button {
                    PrayerTracker.setPrayed(!isPrayed, name: prayer.name, dayKey: todayKey)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    // Dokunuşun işe yaradığı görülsün (yaşlı kullanıcılar emin olamıyordu).
                    showAlarmToast(loc.tf(!isPrayed ? "tracking_marked" : "tracking_unmarked",
                                          !isPrayed ? "%@ kılındı olarak işaretlendi" : "%@ işareti kaldırıldı",
                                          PrayerTracker.namazName(prayer.name)))
                } label: {
                    // Büyük dokunma alanı (44 pt): titrek parmakla da tutsun.
                    Image(systemName: isPrayed ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: AppTheme.scaled(22), weight: .semibold))
                        .foregroundColor(isPrayed ? AppTheme.accent : AppTheme.textTertiary(colorScheme))
                        .frame(width: 44, height: max(44, layout.rowHeight))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(loc.tf(isPrayed ? "home_prayed_on" : "home_prayed_off",
                                           isPrayed ? "%@ kılındı" : "%@ kılınmadı", loc.x(prayer.name)))
            } else {
                Color.clear.frame(width: 44, height: layout.rowHeight)
            }

            // Güneş bir namaz vakti değil: zil yok, hizayı korumak için boşluk.
            if isPrayer {
                let isOn = alarmEnabled[prayer.name] ?? false
                Button {
                    toggleAlarm(prayer.name)
                } label: {
                    Image(systemName: isOn ? "bell.fill" : "bell.slash")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(isOn ? AppTheme.accent : AppTheme.textTertiary(colorScheme))
                        .frame(width: 36, height: layout.rowHeight)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(loc.tf(isOn ? "home_alarm_on" : "home_alarm_off", isOn ? "%@ alarmı açık" : "%@ alarmı kapalı", loc.x(prayer.name)))
                .accessibilityHint(loc.t("home_bell_hint", fallback: "Alarm için zile dokun"))
            } else {
                Color.clear.frame(width: 36, height: layout.rowHeight)
            }
        }
        .frame(height: layout.rowHeight)
    }

    // MARK: - Alarm zili

    private func reloadPrayed() {
        let key = todayKey
        prayedToday = Set(NotificationManager.prayerNames.filter { PrayerTracker.isPrayed($0, dayKey: key) })
    }

    private func reloadAlarmStates() {
        alarmEnabled = Dictionary(uniqueKeysWithValues: NotificationManager.prayerNames.map { ($0, NotificationManager.isPrayerEnabled($0)) })
    }

    /// Ana sayfadaki zile dokununca o vaktin alarmını açar/kapatır.
    /// Bildirim izni hiç sorulmadıysa önce sorar; reddedildiyse Ayarlar'a yönlendirir.
    private func toggleAlarm(_ name: String) {
        let newValue = !(alarmEnabled[name] ?? false)
        NotificationManager.shared.authorizationStatus { status in
            switch status {
            case .denied:
                showNotificationsDenied = true
            case .notDetermined where newValue:
                NotificationManager.shared.requestAuthorization { granted in
                    guard granted else {
                        showNotificationsDenied = true
                        return
                    }
                    NotificationManager.markFirstGrantDefaultsApplied()
                    applyAlarm(newValue, for: name)
                }
            default:
                applyAlarm(newValue, for: name)
            }
        }
    }

    private func applyAlarm(_ enabled: Bool, for name: String) {
        NotificationManager.setPrayerEnabled(enabled, for: name)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        showAlarmToast(Self.alarmToastText(enabled: enabled, prayer: loc.x(name)))
        NotificationManager.shared.rescheduleFromLastKnownLocation()
    }

    static func alarmToastText(enabled: Bool, prayer: String) -> String {
        LocalizationManager.shared.tf(enabled ? "home_alarm_toast_on" : "home_alarm_toast_off",
                                      enabled ? "%@ alarmı açıldı" : "%@ alarmı kapatıldı", prayer)
    }

    private func showAlarmToast(_ text: String) {
        alarmToastID += 1
        let id = alarmToastID
        withAnimation(.easeOut(duration: 0.2)) { alarmToast = text }
        UIAccessibility.post(notification: .announcement, argument: text)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            guard alarmToastID == id else { return }
            withAnimation(.easeIn(duration: 0.25)) { alarmToast = nil }
        }
    }

    // MARK: - Yardımcılar

    private func refreshWithCurrentSource() {
        guard let coordinate = effectiveCoordinate else { return }
        applyResolvedLocation(coordinate: coordinate, timeZone: effectiveTimeZone)
    }

    /// Konum (manuel ya da GPS'ten gelen) kesin olarak belli olduğunda
    /// çağrılır. Parametre olarak verilen değerleri kullanır - bir
    /// @Published property'yi callback içinde tekrar okumaya çalışmak
    /// (willSet zamanlamasından dolayı) eski değeri döndürebiliyor.
    private func applyResolvedLocation(coordinate: CLLocationCoordinate2D, timeZone: TimeZone) {
        prayerViewModel.start(coordinate: coordinate, timeZone: timeZone)
        updateClock()

        // Bildirim planlaması ve arka plan yenilemesi için en güncel
        // konumu sakla ve yeniden planla.
        let defaults = UserDefaults.standard
        let cityName = effectiveCityName
        defaults.set(coordinate.latitude, forKey: "lastKnownLatitude")
        defaults.set(coordinate.longitude, forKey: "lastKnownLongitude")
        defaults.set(timeZone.identifier, forKey: "lastKnownTimeZoneID")
        if cityName != locationManager.waitingText {
            defaults.set(cityName, forKey: "lastKnownCityName")
        }
        NotificationManager.shared.rescheduleAll(coordinate: coordinate, timeZone: timeZone)
        WatchSync.shared.push()

        // Widget'lar birkaç günlük vakti okuyup doğru günü kendileri seçer.
        PrayerWidgetData.save(
            cityName: cityName,
            timeZone: timeZone,
            days: PrayerCalculation.upcomingDays(PrayerWidgetData.storedDayCount, coordinate: coordinate, timeZone: timeZone)
        )
    }

    private func formattedTime(_ date: Date) -> String {
        DisplayFormat.time(date, timeZone: effectiveTimeZone, locale: loc.locale)
    }

    private func updateClock() {
        currentTimeText = DisplayFormat.time(DebugClock.now, timeZone: effectiveTimeZone, locale: loc.locale, seconds: true)
    }
}

#Preview {
    HomeView()
}
