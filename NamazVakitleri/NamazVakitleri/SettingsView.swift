import SwiftUI
import UIKit
import CoreLocation
import Adhan
import StoreKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var notificationManager = NotificationManager.shared
    @ObservedObject private var loc = LocalizationManager.shared
    @ObservedObject private var adConsent = AdConsentManager.shared
    @Environment(\.requestReview) private var requestReview
    @AppStorage("isDarkTheme") private var isDarkTheme: Bool = false

    @AppStorage("useManualLocation") private var useManualLocation: Bool = false
    @AppStorage("manualProvinceName") private var manualProvinceName: String = ""
    @AppStorage("manualLatitude") private var manualLatitude: Double = 0
    @AppStorage("manualLongitude") private var manualLongitude: Double = 0

    @AppStorage(NotificationManager.prayerOffsetKey) private var prayerOffsetMinutes: Int = 0
    @AppStorage(NotificationManager.zikirEnabledKey) private var zikirEnabled: Bool = false
    @AppStorage(NotificationManager.quranEnabledKey) private var quranEnabled: Bool = false
    @AppStorage(NotificationManager.ayahEnabledKey) private var ayahEnabled: Bool = false
    @AppStorage(NotificationManager.fridayEnabledKey) private var fridayEnabled: Bool = true
    @AppStorage(NotificationManager.religiousDaysEnabledKey) private var religiousDaysEnabled: Bool = true
    @AppStorage(NotificationManager.sahurEnabledKey) private var sahurEnabled: Bool = true
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var alarmTestSeconds = 0
    @State private var realAlarm = PrayerAlarms.isEnabled
    @State private var realAlarmDenied = false
    @State private var alarmChoiceRefresh = 0

    /// Son bilinen konum Türkiye'de mi? (Diyanet uyumu "en fazla 1 dk" sadece Türkiye için ölçüldü.)
    static var locationIsInTurkey: Bool {
        let tz = UserDefaults.standard.string(forKey: "lastKnownTimeZoneID") ?? TimeZone.current.identifier
        return tz == "Europe/Istanbul" || tz == "Asia/Istanbul"
    }

    private func startAlarmTestCountdown() {
        alarmTestSeconds = 5
        for k in 1...5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(k)) { alarmTestSeconds = max(0, 5 - k) }
        }
    }

    @State private var methodRefresh = 0
    @ObservedObject private var audioStore = QuranAudioStore.shared
    @AppStorage("showKerahat") private var showKerahat: Bool = true
    @AppStorage(NotificationManager.sahurMinutesKey) private var sahurMinutes: Int = 45


    /// Namaz vakti anahtarları. @State ile tutuyoruz ki dokununca ekran
    /// anında güncellensin (UserDefaults'a doğrudan bağlı Binding bunu yapmıyordu).
    @State private var prayerEnabled: [String: Bool] = Dictionary(
        uniqueKeysWithValues: NotificationManager.prayerNames.map { ($0, NotificationManager.isPrayerEnabled($0)) }
    )
    /// Kullanıcı bildirim iznini reddettiyse true; sayfada uyarı gösterilir.
    @State private var notificationsDenied = false
    @State private var showContactCopied = false
    static let contactEmail = "info@kocaksefa.com"

    /// Uygulamanın gerçek sürümü (Xcode'daki Version ve Build), ör. "1.0 (1)".
    static var appVersionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    // Vakit ince ayarı: @State kullanıyoruz çünkü UserDefaults'a doğrudan
    // yazmak SwiftUI'a "ekranı yeniden çiz" sinyali vermiyordu - bu yüzden
    // değişiklik ancak ekranı kapatıp açınca görünüyordu.
    @State private var fajrAdjust = PrayerCalculation.manualAdjustment(for: "fajr")
    @State private var dhuhrAdjust = PrayerCalculation.manualAdjustment(for: "dhuhr")
    @State private var asrAdjust = PrayerCalculation.manualAdjustment(for: "asr")
    @State private var maghribAdjust = PrayerCalculation.manualAdjustment(for: "maghrib")
    @State private var ishaAdjust = PrayerCalculation.manualAdjustment(for: "isha")

    var body: some View {
        #if DEBUG
        // Ekran resmi: -uiSettingsPage notifications (Bildirimler sayfası doğrudan açılır)
        if UserDefaults.standard.string(forKey: "uiSettingsPage") == "notifications" {
            NavigationView { notificationsPage }
        } else {
            hub
        }
        #else
        hub
        #endif
    }

    private var hub: some View {
        NavigationView {
            List {
                Section {
                    NavigationLink {
                        appearancePage
                    } label: {
                        hubRow(icon: "paintbrush.fill", color: .purple,
                               title: loc.t("settings_group_appearance", fallback: "Görünüm ve Dil"),
                               detail: loc.language.displayName)
                    }
                    NavigationLink {
                        locationPage
                    } label: {
                        hubRow(icon: "location.fill", color: .blue,
                               title: loc.t("settings_group_location", fallback: "Konum"),
                               detail: useManualLocation
                                   ? (manualProvinceName.isEmpty ? loc.t("settings_not_selected", fallback: "Seçilmedi") : manualProvinceName)
                                   : loc.t("settings_auto_location", fallback: "Otomatik"))
                    }
                }

                Section {
                    NavigationLink {
                        notificationsPage
                    } label: {
                        hubRow(icon: "bell.badge.fill", color: .red,
                               title: loc.t("settings_group_notifications", fallback: "Bildirimler"))
                    }
                    NavigationLink {
                        adjustPage
                    } label: {
                        hubRow(icon: "slider.horizontal.3", color: .orange,
                               title: loc.t("settings_adjust", fallback: "Vakit İnce Ayarı"))
                    }
                    NavigationLink {
                        kerahatPage
                    } label: {
                        hubRow(icon: "exclamationmark.triangle.fill", color: .yellow,
                               title: loc.t("settings_kerahat_page", fallback: "Kerahat Vakitleri"),
                               detail: showKerahat ? loc.t("common_on", fallback: "Açık") : loc.t("common_off", fallback: "Kapalı"))
                    }
                }

                Section(loc.t("settings_support", fallback: "Destek")) {
                    Button {
                        if let url = ReviewManager.writeReviewURL {
                            UIApplication.shared.open(url)
                        } else {
                            requestReview()
                        }
                    } label: {
                        hubRow(icon: "star.fill", color: .yellow,
                               title: loc.t("settings_rate_us", fallback: "Bizi Değerlendir"))
                    }
                    .foregroundColor(.primary)

                    Button {
                        guard let url = URL(string: "mailto:\(Self.contactEmail)") else { return }
                        UIApplication.shared.open(url) { opened in
                            // Telefonda e-posta uygulaması yoksa hiçbir şey
                            // olmuyordu: adresi kopyalayıp kullanıcıya söyle.
                            if !opened {
                                UIPasteboard.general.string = Self.contactEmail
                                showContactCopied = true
                            }
                        }
                    } label: {
                        hubRow(icon: "envelope.fill", color: .green,
                               title: loc.t("settings_contact", fallback: "İletişim"))
                    }
                    .foregroundColor(.primary)
                }

                Section {
                    NavigationLink {
                        aboutView
                    } label: {
                        hubRow(icon: "info.circle.fill", color: .gray,
                               title: loc.t("settings_about", fallback: "Hakkında"))
                    }
                    NavigationLink {
                        privacyView
                    } label: {
                        hubRow(icon: "hand.raised.fill", color: .indigo,
                               title: loc.t("settings_privacy", fallback: "Gizlilik Politikası"))
                    }
                }

                Section(loc.t("settings_ad", fallback: "Reklam")) {
                    if adConsent.privacyOptionsRequired {
                        Button {
                            adConsent.presentPrivacyOptions()
                        } label: {
                            hubRow(icon: "checkmark.shield.fill", color: .teal,
                                   title: loc.t("settings_ad_privacy", fallback: "Reklam Gizlilik Tercihleri"))
                        }
                        .foregroundColor(.primary)
                    }
                    AdBannerView()
                        .frame(height: 50)
                }
            }
            .listStyle(.insetGrouped)
            .alert(loc.t("contact_copied_title", fallback: "E-posta adresi kopyalandı"), isPresented: $showContactCopied) {
                Button(loc.t("common_ok", fallback: "Tamam"), role: .cancel) {}
            } message: {
                Text(loc.tf("contact_copied_body", "Bu telefonda e-posta uygulaması bulunamadı. Adresimiz panoya kopyalandı: %@", Self.contactEmail))
            }
            .navigationTitle(loc.t("settings_title", fallback: "Ayarlar"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel(loc.t("common_close", fallback: "Kapat"))
                }
            }
        }
        // Açık pencere de temayı hemen izlesin (tema değişince Ayarlar
        // kapanmıyor artık; bu satır olmadan pencere eski renkte kalıyordu).
        .preferredColorScheme(isDarkTheme ? .dark : .light)
    }

    // MARK: - Alt sayfalar (ana ekrandan gruplanmış bağlantılarla açılır)

    private var appearancePage: some View {
        Form {
            Section {
                Picker(loc.t("settings_theme", fallback: "Tema"), selection: $isDarkTheme) {
                    Text(loc.t("settings_light")).tag(false)
                    Text(loc.t("settings_dark")).tag(true)
                }
                .pickerStyle(.segmented)
            } header: {
                Text(loc.t("settings_appearance"))
            }

            Section {
                Picker(selection: $loc.language) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                } label: {
                    Label(loc.t("settings_language"), systemImage: "globe")
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text(loc.t("settings_language"))
            }
        }
        .navigationTitle(loc.t("settings_group_appearance", fallback: "Görünüm ve Dil"))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: loc.language) { _, _ in handleNotificationPrefChange() }
    }

    private var locationPage: some View {
        LocationSettingsPage()
    }

    private var notificationsPage: some View {
        Form {
            if notificationsDenied {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(loc.t("settings_notif_denied", fallback: "Bildirimler kapalı. Namaz alarmları gelmez."), systemImage: "bell.slash.fill")
                            .foregroundColor(.red)
                        Button(loc.t("settings_open_ios_settings", fallback: "iPhone Ayarları'nı Aç")) {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .foregroundColor(AppTheme.accent)
                    }
                }
            }

            Section {
                ForEach(NotificationManager.prayerNames, id: \.self) { name in
                    Toggle(loc.x(name), isOn: prayerBinding(name))
                        .tint(AppTheme.accent)
                }

                Picker(loc.t("settings_notif_time", fallback: "Bildirim Zamanı"), selection: $prayerOffsetMinutes) {
                    Text(loc.t("settings_on_time", fallback: "Vaktinde")).tag(0)
                    Text(loc.t("settings_3min", fallback: "3 Dakika Önce")).tag(3)
                }
                .pickerStyle(.segmented)
                .onChange(of: prayerOffsetMinutes) { _, _ in handleNotificationPrefChange() }

                ForEach(NotificationManager.soundOptions, id: \.id) { option in
                    soundOptionRow(option)
                }

                Toggle(isOn: $realAlarm) {
                    Label(loc.t("settings_real_alarm", fallback: "Gerçek alarm (sessiz modda da çalar)"), systemImage: "alarm.fill")
                }
                .tint(AppTheme.accent)
                .onChange(of: realAlarm) { _, on in
                    guard on != PrayerAlarms.isEnabled else { return }
                    if on {
                        PrayerAlarms.enable { granted in
                            realAlarm = granted
                            realAlarmDenied = !granted
                            handleNotificationPrefChange()
                        }
                    } else {
                        PrayerAlarms.disable()
                        realAlarmDenied = false
                        handleNotificationPrefChange()
                    }
                }
                if realAlarm {
                    ForEach(NotificationManager.prayerNames, id: \.self) { name in
                        Toggle(isOn: Binding(
                            get: { _ = alarmChoiceRefresh; return PrayerAlarms.isChosen(name) },
                            set: { PrayerAlarms.setChosen($0, name); alarmChoiceRefresh += 1; handleNotificationPrefChange() })) {
                            Text(loc.tf("settings_alarm_for", "%@: alarm", loc.x(name)))
                                .font(.subheadline)
                        }
                        .tint(AppTheme.accent)
                        .padding(.leading, 28)
                        .id("alarm-\(name)-\(alarmChoiceRefresh)")
                    }
                    Toggle(isOn: Binding(
                        get: { _ = alarmChoiceRefresh; return PrayerAlarms.skipFriday },
                        set: { UserDefaults.standard.set($0, forKey: PrayerAlarms.skipFridayKey); alarmChoiceRefresh += 1; handleNotificationPrefChange() })) {
                        Text(loc.t("settings_alarm_skip_friday", fallback: "Cuma öğle alarmı çalmasın"))
                            .font(.subheadline)
                    }
                    .tint(AppTheme.accent)
                    .padding(.leading, 28)
                }
                if realAlarmDenied {
                    Label(loc.t("settings_real_alarm_denied", fallback: "Alarm izni verilmedi. Ayarlar > Safa > Alarmlar'dan açabilirsin."), systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button(loc.t("settings_try_alarm", fallback: "Alarm Görünümünü Şimdi Dene")) {
                    if PrayerAlarms.isActive {
                        PrayerAlarms.scheduleTest()
                        startAlarmTestCountdown()
                        return
                    }
                    NotificationManager.shared.requestAuthorization { granted in
                        guard granted else { return }
                        NotificationManager.shared.scheduleTestPrayerAlarm()
                        // Basınca hiçbir şey olmuyor sanılıyordu: geri sayım göster.
                        DispatchQueue.main.async { startAlarmTestCountdown() }
                    }
                }
                .foregroundColor(AppTheme.accent)
                if alarmTestSeconds > 0 {
                    Label(loc.tf("settings_try_alarm_countdown", "Deneme alarmı %d saniye sonra gelecek", alarmTestSeconds), systemImage: "timer")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(loc.t("settings_prayer_notifs", fallback: "Namaz Vakti Bildirimleri"))
            } footer: {
                Text(loc.t("settings_prayer_notifs_footer2", fallback: "Bildirim almak istediğin vakitleri seç; hepsi aynı zaman tercihini kullanır. Bir sese dokununca seçilir, ▶︎ düğmesi sesi dinletir. Namaz bildirimleri \"Zamana Duyarlı\" gönderilir: Odak ve Rahatsız Etme modundayken de ekrana gelir. Telefon sessiz moddaysa ses çalmaz, sadece titreşir. \"Kıldım\" / \"Birazdan Hatırlat\" düğmeleri için bildirime basılı tut. Deneme düğmesi 5 saniye sonra örnek bir bildirim gönderir.") + "\n\n" + loc.t("settings_real_alarm_footer", fallback: "Gerçek alarm, saat uygulamasındaki alarm gibi sessiz modda ve Odak'ta da sesli çalar, kilit ekranında tam ekran görünür. Bu yüzden başta sadece İmsak (sabah uyanmak için) seçilidir; gündüz vakitlerinde alarm toplantıda, derste ya da camide de çalar. Seçtiğin vakitlerin önümüzdeki 3 günü kurulur; \"Ertele\" 10 dakika sonra tekrar çaldırır. Alarm çalan vakitlerin bildirimi sessiz gelir; \"Kıldım\" düğmesi bildirimde kalır."))
            }

            Section {
                Toggle(isOn: $zikirEnabled) {
                    Label(loc.t("settings_zikir_reminder", fallback: "Zikir Hatırlatıcı"), systemImage: "circle.hexagongrid.fill")
                }
                .tint(AppTheme.accent)
                .onChange(of: zikirEnabled) { _, _ in handleNotificationPrefChange() }

                Toggle(isOn: $quranEnabled) {
                    Label(loc.t("settings_quran_reminder", fallback: "Kur'an Okuma Hatırlatıcı"), systemImage: "book.fill")
                }
                .tint(AppTheme.accent)
                .onChange(of: quranEnabled) { _, _ in handleNotificationPrefChange() }

                Toggle(isOn: $ayahEnabled) {
                    Label(loc.t("settings_ayah_of_day", fallback: "Günün Ayeti"), systemImage: "sparkles")
                }
                .tint(AppTheme.accent)
                .onChange(of: ayahEnabled) { _, _ in handleNotificationPrefChange() }

                Toggle(isOn: $fridayEnabled) {
                    Label(loc.t("settings_friday_reminder", fallback: "Cuma Hatırlatıcısı"), systemImage: "calendar.badge.clock")
                }
                .tint(AppTheme.accent)
                .onChange(of: fridayEnabled) { _, _ in handleNotificationPrefChange() }

                Toggle(isOn: $religiousDaysEnabled) {
                    Label(loc.t("settings_religious_reminder", fallback: "Kandil ve Bayram Hatırlatıcısı"), systemImage: "moon.stars")
                }
                .tint(AppTheme.accent)
                .onChange(of: religiousDaysEnabled) { _, _ in handleNotificationPrefChange() }
            } header: {
                Text(loc.t("settings_reminders", fallback: "Hatırlatıcılar"))
            } footer: {
                Text(loc.t("settings_reminders_footer", fallback: "Günün rastgele saatlerinde nazik birer hatırlatma bildirimi gönderilir."))
            }

            Section {
                Toggle(isOn: $sahurEnabled) {
                    Label(loc.t("settings_sahur", fallback: "Sahur Alarmı"), systemImage: "moon.haze.fill")
                }
                .tint(AppTheme.accent)
                .onChange(of: sahurEnabled) { _, _ in handleNotificationPrefChange() }

                if sahurEnabled {
                    Picker(loc.t("settings_sahur_before", fallback: "İmsak'tan önce"), selection: $sahurMinutes) {
                        Text(loc.tf("settings_min_suffix", "%d dk", 30)).tag(30)
                        Text(loc.tf("settings_min_suffix", "%d dk", 45)).tag(45)
                        Text(loc.tf("settings_min_suffix", "%d dk", 60)).tag(60)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: sahurMinutes) { _, _ in handleNotificationPrefChange() }
                }
            } header: {
                Text(loc.t("settings_ramadan", fallback: "Ramazan"))
            } footer: {
                Text(loc.t("settings_sahur_footer", fallback: "Sadece Ramazan günlerinde, İmsak'tan seçtiğin kadar önce çalar."))
            }
        }
        .navigationTitle(loc.t("settings_group_notifications", fallback: "Bildirimler"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { refreshNotificationStatus() }
    }

    private func refreshNotificationStatus() {
        NotificationManager.shared.authorizationStatus { status in
            notificationsDenied = status == .denied
        }
    }

    /// Bugünün kerahat vakitleri (kayıtlı konuma göre).
    private var todayKerahatWindows: [KerahatTimes.Window] {
        guard let (coordinate, tz) = NotificationManager.lastKnownLocation(),
              let times = PrayerCalculation.times(on: Date(), coordinate: coordinate, timeZone: tz) else { return [] }
        return KerahatTimes.windows(for: times)
    }

    private var kerahatPage: some View {
        Form {
            Section {
                Toggle(isOn: $showKerahat) {
                    Label(loc.t("settings_kerahat", fallback: "Kerahat Vaktini Göster"), systemImage: "exclamationmark.triangle")
                }
                .tint(AppTheme.accent)
            } footer: {
                Text(loc.t("settings_kerahat_footer", fallback: "Kerahat vaktinde ana sayfada bir uyarı çıkar: güneş doğduktan sonraki ve akşamdan önceki yaklaşık 45 dakika, öğleden önceki yaklaşık 10 dakika (istiva). Süreler takvimlerdeki yaygın uygulamadır; kesin vakitler yere ve güne göre değişir. Siri'ye \"Safa kerahat vakti mi\" ya da \"Safa sıradaki namaz\" diyebilirsin."))
            }

            if !todayKerahatWindows.isEmpty {
                Section(loc.t("kerahat_today", fallback: "Bugün (yaklaşık)")) {
                    ForEach(todayKerahatWindows, id: \.start) { w in
                        HStack {
                            Text(loc.t(w.kind.localizationKey, fallback: w.kind.turkishName))
                            Spacer()
                            Text("\(kerahatTime(w.start)) – \(kerahatTime(w.end))")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(loc.t("settings_kerahat_page", fallback: "Kerahat Vakitleri"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func kerahatTime(_ date: Date) -> String {
        DisplayFormat.time(date, timeZone: NotificationManager.lastKnownLocation()?.1 ?? .current, locale: loc.locale)
    }

    private var adjustPage: some View {
        Form {
            Section {
                Picker(loc.t("method_title", fallback: "Hesaplama yöntemi"), selection: Binding(
                    get: { PrayerCalculation.selectedMethod },
                    set: { PrayerCalculation.setMethod($0); methodRefresh += 1; rescheduleNotifications() }
                )) {
                    ForEach(PrayerCalculation.Method.allCases) { m in
                        Text(loc.t(m.titleKey, fallback: m.turkishTitle)).tag(m)
                    }
                }
                .id(methodRefresh)
            } footer: {
                Text(loc.t("method_footer", fallback: "Türkiye'de Diyanet yöntemi kullan. Yurt dışında vakitler gittiğin caminin takviminden farklıysa (özellikle İmsak ve Yatsı), o ülkede kullanılan yöntemi seç."))
            }
            Section {
                prayerAdjustRow(title: loc.x("İmsak"), key: "fajr", value: $fajrAdjust)
                prayerAdjustRow(title: loc.x("Öğle"), key: "dhuhr", value: $dhuhrAdjust)
                prayerAdjustRow(title: loc.x("İkindi"), key: "asr", value: $asrAdjust)
                prayerAdjustRow(title: loc.x("Akşam"), key: "maghrib", value: $maghribAdjust)
                prayerAdjustRow(title: loc.x("Yatsı"), key: "isha", value: $ishaAdjust)
            } header: {
                Text(loc.t("settings_adjust", fallback: "Vakit İnce Ayarı"))
            } footer: {
                let _ = methodRefresh
                if PrayerCalculation.selectedMethod == .diyanet && !Self.locationIsInTurkey {
                    Text(loc.t("settings_adjust_footer_abroad", fallback: "Vakitler Diyanet yöntemiyle hesaplanır. Yurt dışında Diyanet'in o şehir için yayımladığı takvim, özellikle İmsak ve Yatsı'da birkaç dakika farklı olabilir. Gittiğin camiye göre burada dakika ayarı yapabilirsin."))
                } else if PrayerCalculation.selectedMethod == .diyanet {
                    Text(loc.t("settings_adjust_footer", fallback: "Vakitler Diyanet yöntemiyle hesaplanır ve resmi tabloyla çoğu gün tam tutar (en fazla 1 dakika fark). Semtindeki camiye göre burada dakika ayarı yapabilirsin."))
                } else {
                    Text(loc.tf("settings_adjust_footer_other", "Vakitler %@ yöntemiyle hesaplanır. Gittiğin caminin takvimine göre burada dakika ayarı yapabilirsin.",
                                loc.t(PrayerCalculation.selectedMethod.titleKey, fallback: PrayerCalculation.selectedMethod.turkishTitle)))
                }
            }
        }
        .navigationTitle(loc.t("settings_adjust", fallback: "Vakit İnce Ayarı"))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Çok büyük yazıda başlık ve değer yan yana sığmıyor ("Görünü m ve Dil" diye
    /// kelime ortasından bölünüyordu): değer başlığın altına geçer.
    private func hubRow(icon: String, color: Color, title: String, detail: String? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(color))

            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    if let detail, !detail.isEmpty {
                        Text(detail).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            } else {
                Text(title)
                Spacer(minLength: 8)
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .contentShape(Rectangle())
    }

    private func prayerAdjustRow(title: String, key: String, value: Binding<Int>) -> some View {
        Stepper(value: value, in: -15...15) {
            HStack {
                Text(title)
                Spacer()
                Text(value.wrappedValue == 0 ? loc.t("settings_not_adjusted", fallback: "Ayarlanmadı") : (value.wrappedValue > 0 ? "+" + loc.tf("settings_min_suffix", "%d dk", value.wrappedValue) : loc.tf("settings_min_suffix", "%d dk", value.wrappedValue)))
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: value.wrappedValue) { _, newValue in
            PrayerCalculation.setManualAdjustment(newValue, for: key)
            handleNotificationPrefChange()
        }
    }

    // MARK: - Bildirim yardımcıları

    private func soundOptionRow(_ option: (id: String, label: String, fileName: String)) -> some View {
        let isSelected = notificationManager.selectedSoundChoice == option.id
        let isPlaying = notificationManager.currentlyPlayingFileName == option.fileName

        return HStack {
            // Satırın geri kalanına basmak SADECE seçer, sesi çalmaz.
            Button {
                notificationManager.selectSound(option.id)
                handleNotificationPrefChange()
            } label: {
                HStack {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? AppTheme.accent : .secondary)
                        .font(.system(size: 20))

                    Text(loc.x(option.label))
                        .foregroundColor(.primary)

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Sadece bu ikon sesi çalar/durdurur.
            Button {
                if isPlaying {
                    notificationManager.stopSoundPreview()
                } else {
                    notificationManager.playSoundPreview(fileName: option.fileName)
                }
            } label: {
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle")
                    .foregroundColor(AppTheme.accent)
                    .font(.system(size: 22))
            }
            .buttonStyle(.plain)
        }
    }

    private func prayerBinding(_ name: String) -> Binding<Bool> {
        Binding(
            get: { prayerEnabled[name] ?? false },
            set: { newValue in
                prayerEnabled[name] = newValue
                NotificationManager.setPrayerEnabled(newValue, for: name)
                handleNotificationPrefChange()
            }
        )
    }

    private func handleNotificationPrefChange() {
        NotificationManager.shared.requestAuthorization { granted in
            notificationsDenied = !granted
            guard granted else { return }
            rescheduleNotifications()
        }
    }

    /// HomeView, konum her çözüldüğünde bunu UserDefaults'a yazar;
    /// burada okuyup bildirimleri güncel konuma göre yeniden planlarız.
    private func rescheduleNotifications() {
        let lat = UserDefaults.standard.double(forKey: "lastKnownLatitude")
        let lon = UserDefaults.standard.double(forKey: "lastKnownLongitude")
        guard lat != 0 || lon != 0 else { return }
        let tzID = UserDefaults.standard.string(forKey: "lastKnownTimeZoneID") ?? TimeZone.current.identifier
        let timeZone = TimeZone(identifier: tzID) ?? .current
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        NotificationManager.shared.rescheduleAll(coordinate: coordinate, timeZone: timeZone)
    }

    private var aboutView: some View {
        List {
            Text(loc.t("settings_about_text", fallback: "Safa Namaz Vakitleri, günlük namaz vakitlerini, kıble yönünü, Kur'an-ı Kerim'i ve daha fazlasını tek bir yerde sunan bir uygulamadır."))
            HStack {
                Text(loc.t("settings_version", fallback: "Sürüm"))
                Spacer()
                Text(Self.appVersionText).foregroundStyle(.secondary)
            }

            Section(loc.t("audio_storage_title", fallback: "İndirilen Hafız Sesleri")) {
                let _ = audioStore.revision
                HStack {
                    Text(loc.t("audio_storage_size", fallback: "Kapladığı yer"))
                    Spacer()
                    Text(DisplayFormat.oneDecimal(Double(audioStore.totalBytes) / 1_000_000) + " MB")
                        .foregroundStyle(.secondary)
                }
                if audioStore.totalBytes > 0 {
                    Button(loc.t("audio_delete_all", fallback: "Tümünü Sil"), role: .destructive) { audioStore.deleteAll() }
                }
            }

            Section(loc.t("sources_title", fallback: "Kaynaklar")) {
                sourceRow(loc.t("sources_quran_text", fallback: "Kur'an metni"), "Tanzil Project (tanzil.net) · alquran.cloud")
                if let meal = Self.mealSourceName(loc.language) {
                    sourceRow(loc.t("sources_meal", fallback: "Türkçe meal"), "\(meal) · alquran.cloud")
                }
                sourceRow(loc.t("sources_hadith", fallback: "Hadis"), loc.t("sources_hadith_value", fallback: "İmam Nevevî, Kırk Hadis · hadith-api (açık kaynak)"))
                sourceRow(loc.t("sources_audio", fallback: "Hafız sesi"), "\(RecitationPlayer.localizedReciterName) · Islamic Network (alquran.cloud)")
                sourceRow(loc.t("sources_times", fallback: "Namaz vakitleri"),
                          PrayerCalculation.selectedMethod == .diyanet
                            ? loc.t("sources_times_value", fallback: "Adhan kütüphanesi, Türkiye (Diyanet) hesaplama yöntemi")
                            : "Adhan · " + loc.t(PrayerCalculation.selectedMethod.titleKey, fallback: PrayerCalculation.selectedMethod.turkishTitle))
                Text(loc.t("sources_note", fallback: "Hafız kayıtlarının hakları okuyucuya aittir. Ses ücretsiz sunulur."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(loc.t("about_disclaimer", fallback: "Safa Namaz Vakitleri, Diyanet İşleri Başkanlığı'nın ya da Türkiye Diyanet Vakfı'nın resmi uygulaması değildir ve bu kurumlarla bir bağı yoktur. Vakitler, Diyanet'in hesaplama yöntemiyle telefonunda hesaplanır."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(loc.t("settings_about", fallback: "Hakkında"))
    }

    /// Gösterilen mealin kaynağı (Arapça'da meal yok).
    static func mealSourceName(_ lang: AppLanguage) -> String? {
        switch lang {
        case .turkish: return "Diyanet Vakfı"
        case .english: return "Marmaduke Pickthall (1930)"
        case .german: return "Marmaduke Pickthall (1930, Englisch)"
        case .arabic: return nil
        }
    }

    private func sourceRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(value).font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var privacyView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(loc.t("settings_privacy", fallback: "Gizlilik Politikası"))
                    .font(.title2.bold())

                Text(PrivacyPolicyText.updated(loc.language))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                ForEach(PrivacyPolicyText.sections.indices, id: \.self) { i in
                    let section = PrivacyPolicyText.sections[i]
                    privacySection(
                        title: section.title[loc.language] ?? section.title[.turkish] ?? "",
                        body: section.body[loc.language] ?? section.body[.turkish] ?? ""
                    )
                }

                VStack(alignment: .leading, spacing: 10) {
                    Link(destination: PrivacyPolicyText.webURL) {
                        Label(loc.t("privacy_read_web", fallback: "Web'de oku: kocaksefa.com/safa-app"), systemImage: "safari")
                    }
                    if let mail = URL(string: "mailto:\(PrivacyPolicyText.contactEmail)") {
                        Link(destination: mail) {
                            Label(PrivacyPolicyText.contactEmail, systemImage: "envelope")
                        }
                    }
                }
                .font(.subheadline.weight(.semibold))
                .padding(.top, 4)
            }
            .padding()
        }
        .navigationTitle(loc.t("settings_privacy", fallback: "Gizlilik Politikası"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func privacySection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

/// Ayarlar > Konum sayfası. Kendi durumunu (hangi pencerenin açık olduğu)
/// kendisi tutar. Seçim menüsü kapanmadan yeni pencere açılmaya
/// çalışılınca iOS isteği yok sayıyordu; bu yüzden pencere, menü
/// kapandıktan sonra açılır.
private struct LocationSettingsPage: View {
    @ObservedObject private var loc = LocalizationManager.shared

    @AppStorage("useManualLocation") private var useManualLocation: Bool = false
    @AppStorage("manualProvinceName") private var manualProvinceName: String = ""
    @AppStorage("manualLatitude") private var manualLatitude: Double = 0
    @AppStorage("manualLongitude") private var manualLongitude: Double = 0

    @State private var showProvincePicker = false
    @State private var showAddressSearch = false
    @State private var showLocationOptions = false

    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: "mappin.circle.fill").foregroundColor(AppTheme.accent)
                    Text(loc.t("settings_current_place", fallback: "Şu anki konum"))
                    Spacer()
                    Text(UserDefaults.standard.string(forKey: "lastKnownCityName") ?? "—")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
            Section(loc.t("settings_general")) {
                Toggle(isOn: $useManualLocation) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(loc.t("settings_manual_toggle", fallback: "Konumu elle seç"))
                            Text(loc.t("settings_manual_toggle_sub", fallback: "Kapalıyken telefon konumunu kendisi bulur. Açıkken senin seçtiğin il ya da adres kullanılır."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "location.fill")
                            .foregroundColor(AppTheme.accent)
                    }
                }

                if useManualLocation {
                    Button {
                        showLocationOptions = true
                    } label: {
                        HStack {
                            Label(loc.t("settings_manual_location", fallback: "Manuel Konum"), systemImage: "mappin.and.ellipse")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(manualProvinceName.isEmpty ? loc.t("settings_not_selected", fallback: "Seçilmedi") : manualProvinceName)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .confirmationDialog(loc.t("settings_location_method", fallback: "Konum seçim yöntemi"), isPresented: $showLocationOptions) {
                        Button(loc.t("settings_search_address", fallback: "Mahalle / Adres Ara")) {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showAddressSearch = true }
                        }
                        Button(loc.t("settings_pick_province", fallback: "İl Merkezinden Seç")) {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showProvincePicker = true }
                        }
                    }
                }

            }
        }
        .navigationTitle(loc.t("settings_group_location", fallback: "Konum"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showProvincePicker) {
            ProvincePickerView(
                manualProvinceName: $manualProvinceName,
                manualLatitude: $manualLatitude,
                manualLongitude: $manualLongitude
            )
        }
        .sheet(isPresented: $showAddressSearch) {
            AddressSearchView(
                manualProvinceName: $manualProvinceName,
                manualLatitude: $manualLatitude,
                manualLongitude: $manualLongitude
            )
        }
    }
}

#Preview {
    SettingsView()
}
