#if DEBUG
import Foundation
import CoreLocation
import MapKit
import UserNotifications
import Adhan

/// Otomatik regresyon testleri (sadece DEBUG derlemede).
/// Çalıştırma: uygulamayı `-selfTest` argümanıyla başlat. Sonuçlar konsola
/// "SELFTEST" önekiyle yazılır ve Documents/selftest.txt dosyasına kaydedilir,
/// sonra uygulama kapanır. Test kimlikleri "CLAUDE CODE/TEST_LIST.md" ile aynıdır.
enum SelfTests {
    private static var lines: [String] = []
    private static var passed = 0
    private static var failed = 0
    private static var skipped = 0

    private static func skip(_ id: String, _ name: String, _ reason: String) {
        skipped += 1
        let line = "SELFTEST SKIP \(id) \(name) — \(reason)"
        lines.append(line)
        print(line)
    }

    /// T39: Gerçek telefonda iOS'un bekleyen bildirim listesini okur.
    /// Kullanıcının kendi ayarlarıyla ve son bilinen konumla, uygulamanın
    /// normalde yaptığı planlamayı yapar (test ayarları geri yüklendikten sonra).
    private static func realPendingNotificationsTest() {
        let center = UNUserNotificationCenter.current()
        var status: UNAuthorizationStatus = .notDetermined
        var pending: [UNNotificationRequest] = []
        var finished = false
        center.getNotificationSettings { settings in
            status = settings.authorizationStatus
            finished = true
        }
        spin(until: { finished }, seconds: 5)
        guard status == .authorized else {
            skip("T39", "Gerçek bekleyen bildirimler", "bildirim izni yok (durum=\(status.rawValue))")
            return
        }
        guard NotificationManager.lastKnownLocation() != nil else {
            skip("T39", "Gerçek bekleyen bildirimler", "uygulamada kayıtlı konum yok; önce uygulamayı normal aç")
            return
        }
        finished = false
        NotificationManager.shared.rescheduleFromLastKnownLocation { finished = true }
        spin(until: { finished }, seconds: 20)
        finished = false
        center.getPendingNotificationRequests { list in
            pending = list
            finished = true
        }
        spin(until: { finished }, seconds: 5)
        let ids = pending.map(\.identifier)
        let prayers = ids.filter { $0.hasPrefix("prayer_") && !$0.hasPrefix("prayer_snooze_") && $0 != "prayer_test" }.count
        let enabled = NotificationManager.prayerNames.filter { UserDefaults.standard.bool(forKey: NotificationManager.prayerEnabledKey($0)) }
        let soonest = pending.compactMap { ($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() }.min()
        let soonestText = soonest.map { DateFormatter.localizedString(from: $0, dateStyle: .short, timeStyle: .short) } ?? "-"
        let ok = pending.count <= 64 && (enabled.isEmpty ? prayers == 0 : prayers > 0)
        check("T39", "Gerçek telefonda bekleyen bildirimler doğru", ok,
              "toplam=\(pending.count), namaz=\(prayers), açık vakitler=\(enabled.joined(separator: ",")), en yakın=\(soonestText)")
    }

    private static func spin(until done: () -> Bool, seconds: TimeInterval) {
        let deadline = Date().addingTimeInterval(seconds)
        while !done() && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
    }

    private static func check(_ id: String, _ name: String, _ condition: Bool, _ detail: String = "") {
        if condition { passed += 1 } else { failed += 1 }
        let line = "SELFTEST \(condition ? "PASS" : "FAIL") \(id) \(name)\(detail.isEmpty ? "" : " — \(detail)")"
        lines.append(line)
        print(line)
    }

    static let istanbul = CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784)
    static let istanbulTZ = TimeZone(identifier: "Europe/Istanbul")!

    // MARK: - Kullanıcı ayarlarının korunması

    /// Testler bazı ayarları geçici olarak değiştirir. Kullanıcının gerçek
    /// ayarları bozulmasın diye testten önce TÜM ayarların kopyası bir
    /// dosyaya yazılır, testten sonra geri yüklenir ve diske zorla yazılır.
    /// Uygulama yarıda kapanırsa bir sonraki test başlangıcında önce bu
    /// kopya geri yüklenir.
    private static var backupURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("selftest_settings_backup.plist")
    }
    private static let bundleDomain = Bundle.main.bundleIdentifier ?? "com.kocaksefa.NamazVakitleri"

    private static func snapshotSettings() {
        let app = UserDefaults.standard.persistentDomain(forName: bundleDomain) ?? [:]
        let group = UserDefaults(suiteName: PrayerWidgetData.appGroupID)?.dictionaryRepresentation() ?? [:]
        let groupOwn = group.filter { ["widget_snapshot_v2", "isDarkTheme", "appLanguage"].contains($0.key) }
        let payload: [String: Any] = ["app": app, "group": groupOwn]
        if let url = backupURL, let data = try? PropertyListSerialization.data(fromPropertyList: payload, format: .binary, options: 0) {
            try? data.write(to: url, options: .atomic)
        }
    }

    /// Kopya varsa geri yükler ve dosyayı siler. Geri yüklendiyse true.
    @discardableResult
    private static func restoreSettingsIfNeeded() -> Bool {
        guard let url = backupURL, let data = try? Data(contentsOf: url),
              let payload = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let app = payload["app"] as? [String: Any] else { return false }
        UserDefaults.standard.setPersistentDomain(app, forName: bundleDomain)
        if let group = UserDefaults(suiteName: PrayerWidgetData.appGroupID) {
            for key in ["widget_snapshot_v2", "isDarkTheme", "appLanguage"] {
                group.set((payload["group"] as? [String: Any])?[key], forKey: key)
            }
            group.synchronize()
        }
        UserDefaults.standard.synchronize()
        try? FileManager.default.removeItem(at: url)
        return true
    }

    static func runAndExit() {
        // Önceki bir test yarıda kaldıysa önce kullanıcının ayarlarını geri getir.
        if restoreSettingsIfNeeded() { print("SELFTEST NOTE önceki testten kalan ayar kopyası geri yüklendi") }
        snapshotSettings()
        let defaults = UserDefaults.standard
        let savedKeys = [
            "notif_prayer_enabled_İmsak", "notif_prayer_enabled_Öğle", "notif_prayer_enabled_İkindi",
            "notif_prayer_enabled_Akşam", "notif_prayer_enabled_Yatsı",
            NotificationManager.zikirEnabledKey, NotificationManager.quranEnabledKey,
            NotificationManager.ayahEnabledKey, NotificationManager.fridayEnabledKey,
            NotificationManager.prayerOffsetKey, "prayer_manual_adjust_fajr"
        ]
        let saved = savedKeys.map { ($0, defaults.object(forKey: $0)) }
        defer {
            for (key, value) in saved { defaults.set(value, forKey: key) }
        }

        calculationTests()
        notificationTests()
        widgetTests()
        qiblaTests()
        contentTests()
        networkTests()

        for (key, value) in saved { defaults.set(value, forKey: key) }
        realPendingNotificationsTest()

        let summary = "SELFTEST SUMMARY passed=\(passed) failed=\(failed) skipped=\(skipped) total=\(passed + failed)"
        lines.append(summary)
        print(summary)
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            try? lines.joined(separator: "\n").write(to: dir.appendingPathComponent("selftest.txt"), atomically: true, encoding: .utf8)
        }
        for (key, value) in saved { defaults.set(value, forKey: key) }
        // Kullanıcının ayarlarını tam olarak geri yükle ve diske yaz.
        restoreSettingsIfNeeded()
        // Gerçek bildirim listesini kullanıcının kendi ayarlarıyla yeniden kur.
        if NotificationManager.lastKnownLocation() != nil {
            var done = false
            NotificationManager.shared.rescheduleFromLastKnownLocation { done = true }
            spin(until: { done }, seconds: 20)
        }
        exit(failed == 0 ? 0 : 1)
    }

    // MARK: - Vakit hesabı

    private static func calculationTests() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = istanbulTZ
        let day = cal.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 12))!
        let t = PrayerCalculation.times(on: day, coordinate: istanbul, timeZone: istanbulTZ)
        check("T01", "İstanbul vakitleri hesaplanıyor ve sıralı", {
            guard let t else { return false }
            return t.fajr < t.sunrise && t.sunrise < t.dhuhr && t.dhuhr < t.asr && t.asr < t.maghrib && t.maghrib < t.isha
                && cal.isDate(t.fajr, inSameDayAs: day)
        }())

        let days = PrayerCalculation.upcomingDays(7, coordinate: istanbul, timeZone: istanbulTZ, from: day)
        let gapsOK = zip(days, days.dropFirst()).allSatisfy { abs($1.dayStart.timeIntervalSince($0.dayStart) - 86400) < 1 }
        let orderOK = days.allSatisfy { d in d.times.count == 6 && zip(d.times, d.times.dropFirst()).allSatisfy { $0.time < $1.time } }
        check("T03", "7 günlük vakit listesi (widget verisi)", days.count == 7 && gapsOK && orderOK,
              "gün=\(days.count)")

        let before = PrayerCalculation.manualAdjustment(for: "fajr")
        PrayerCalculation.setManualAdjustment(0, for: "fajr")
        let base = PrayerCalculation.times(on: day, coordinate: istanbul, timeZone: istanbulTZ)?.fajr
        PrayerCalculation.setManualAdjustment(5, for: "fajr")
        let shifted = PrayerCalculation.times(on: day, coordinate: istanbul, timeZone: istanbulTZ)?.fajr
        PrayerCalculation.setManualAdjustment(before, for: "fajr")
        let diff = (shifted?.timeIntervalSince(base ?? Date()) ?? 0) / 60
        check("T04", "Dakika ince ayarı (+5 dk İmsak)", abs(diff - 5) < 0.01, "fark=\(diff) dk")

        let polar = PrayerCalculation.times(on: cal.date(from: DateComponents(year: 2026, month: 6, day: 21, hour: 12))!,
                                            coordinate: CLLocationCoordinate2D(latitude: 89.0, longitude: 0),
                                            timeZone: TimeZone(identifier: "UTC")!)
        let polarVM = PrayerTimeViewModel()
        polarVM.start(coordinate: CLLocationCoordinate2D(latitude: 89.0, longitude: 0), timeZone: TimeZone(identifier: "UTC")!)
        check("T05", "Hesaplanamayan konumda hata durumu gösteriliyor (sonsuz bekleme yok)",
              polarVM.calculationFailed == (polarVM.prayerTimes == nil),
              "hesap=\(polar == nil ? "yok" : "var"), hataDurumu=\(polarVM.calculationFailed)")
    }

    // MARK: - Bildirimler

    private static func notificationTests() {
        let defaults = UserDefaults.standard
        for name in NotificationManager.prayerNames {
            defaults.set(true, forKey: NotificationManager.prayerEnabledKey(name))
        }
        defaults.set(true, forKey: NotificationManager.zikirEnabledKey)
        defaults.set(true, forKey: NotificationManager.quranEnabledKey)
        defaults.set(true, forKey: NotificationManager.ayahEnabledKey)
        defaults.set(true, forKey: NotificationManager.fridayEnabledKey)
        defaults.set(0, forKey: NotificationManager.prayerOffsetKey)

        let nm = NotificationManager.shared
        let requests = nm.buildRequests(coordinate: istanbul, timeZone: istanbulTZ)
        let ids = requests.map(\.identifier)
        let prayerIDs = ids.filter { $0.hasPrefix("prayer_") }
        check("T06", "Bildirim sayısı 64 sınırının altında", requests.count <= 56, "adet=\(requests.count)")
        // Beklenen: 7 günde, şu andan sonraki her İmsak/Öğle/İkindi/Akşam/Yatsı.
        let expectedPrayers = PrayerCalculation.upcomingDays(NotificationManager.prayerWindowDays, coordinate: istanbul, timeZone: istanbulTZ)
            .flatMap { $0.times }
            .filter { $0.name != "Güneş" && $0.time > Date() }
            .count
        check("T07", "Namaz alarmları 7 gün ileri planlanıyor", prayerIDs.count == expectedPrayers && ids.contains("prayer_Yatsı_6"),
              "namaz=\(prayerIDs.count), beklenen=\(expectedPrayers)")
        check("T08", "Hatırlatmalar 3 günle sınırlı", !ids.contains { $0.hasPrefix("zikir_3") || $0.hasPrefix("ayah_3") })
        check("T09", "\"Alarmlar duracak\" güvenlik bildirimi var", ids.contains("keepalive_0"))
        check("T10", "Kimlikler benzersiz", Set(ids).count == ids.count)

        let prayerTriggers = requests.filter { $0.identifier.hasPrefix("prayer_") }.compactMap { $0.trigger as? UNCalendarNotificationTrigger }
        check("T11", "Alarm tetikleyicisinde konumun saat dilimi var",
              !prayerTriggers.isEmpty && prayerTriggers.allSatisfy { $0.dateComponents.timeZone?.identifier == "Europe/Istanbul" })

        // Saat dilimi farklı bir konum: tetikleyicinin gerçek zamanı vakitle aynı olmalı.
        let ny = TimeZone(identifier: "America/New_York")!
        let nyCoord = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let nyReq = nm.buildRequests(coordinate: nyCoord, timeZone: ny).first { $0.identifier == "prayer_Öğle_1" }
        let tomorrow = Calendar(identifier: .gregorian).date(byAdding: .day, value: 1, to: Date())!
        let expected = PrayerCalculation.times(on: tomorrow, coordinate: nyCoord, timeZone: ny)?.dhuhr
        var nyCal = Calendar(identifier: .gregorian); nyCal.timeZone = ny
        let comps = (nyReq?.trigger as? UNCalendarNotificationTrigger)?.dateComponents
        let fire = comps.flatMap { c -> Date? in
            var c2 = c; c2.calendar = nyCal; return c2.date
        }
        let delta = abs((fire?.timeIntervalSince1970 ?? 0) - (expected?.timeIntervalSince1970 ?? 1e9))
        check("T12", "Farklı saat diliminde alarm doğru anda (New York Öğle)", delta < 1.5, "fark=\(Int(delta)) sn")

        check("T13", "Ertelenen ve deneme bildirimleri silinmiyor",
              !NotificationManager.isManagedIdentifier("prayer_snooze_ABC")
              && !NotificationManager.isManagedIdentifier("prayer_test")
              && NotificationManager.isManagedIdentifier("prayer_İmsak_0")
              && NotificationManager.isManagedIdentifier("keepalive_0")
              && NotificationManager.isManagedIdentifier("friday_6_2"))

        for name in NotificationManager.prayerNames {
            defaults.set(false, forKey: NotificationManager.prayerEnabledKey(name))
        }
        let off = nm.buildRequests(coordinate: istanbul, timeZone: istanbulTZ).map(\.identifier)
        check("T14", "Namaz alarmları kapalıyken alarm ve güvenlik bildirimi yok",
              !off.contains { $0.hasPrefix("prayer_") } && !off.contains("keepalive_0"))

        let fridays = ids.filter { $0.hasPrefix("friday_") }
        check("T15", "Cuma hatırlatması en fazla 2", fridays.count <= 2, "adet=\(fridays.count)")

        // T43: Kandil/bayram hatırlatması: 60 gün içindeki ilk 3 dini gün, saat 10:00; kapatılınca hiç yok.
        let savedReligious = defaults.object(forKey: NotificationManager.religiousDaysEnabledKey)
        defaults.set(true, forKey: NotificationManager.religiousDaysEnabledKey)
        let relOn = nm.buildRequests(coordinate: istanbul, timeZone: istanbulTZ).filter { $0.identifier.hasPrefix("religious_") }
        let expectedRel = ReligiousDays.upcoming().filter { $0.date <= Date().addingTimeInterval(60 * 86_400) }.prefix(3).count
        let tenAM = relOn.allSatisfy { ($0.trigger as? UNCalendarNotificationTrigger)?.dateComponents.hour == 10 }
        defaults.set(false, forKey: NotificationManager.religiousDaysEnabledKey)
        let relOff = nm.buildRequests(coordinate: istanbul, timeZone: istanbulTZ).filter { $0.identifier.hasPrefix("religious_") }
        defaults.set(savedReligious, forKey: NotificationManager.religiousDaysEnabledKey)
        check("T43", "Kandil/bayram hatırlatması doğru sayıda, 10:00'da; kapalıyken yok",
              relOn.count == expectedRel && tenAM && relOff.isEmpty, "adet=\(relOn.count), beklenen=\(expectedRel)")

        // T44: 64 sınırı koruması: fazla bildirimde önce hatırlatmalar çıkarılır, namaz alarmları kalır.
        func fake(_ id: String, _ minutes: Double) -> UNNotificationRequest {
            var cal = Calendar(identifier: .gregorian); cal.timeZone = istanbulTZ
            var c = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: Date().addingTimeInterval(minutes * 60))
            c.timeZone = istanbulTZ
            return UNNotificationRequest(identifier: id, content: UNMutableNotificationContent(),
                                         trigger: UNCalendarNotificationTrigger(dateMatching: c, repeats: false))
        }
        let many = (0..<40).map { fake("prayer_x_\($0)", Double($0 + 10)) } + (0..<30).map { fake("zikir_\($0)_0", Double($0 + 5)) }
        let trimmed = NotificationManager.trimmedToBudget(many)
        check("T44", "64 sınırı: 70 bildirim 56'ya iner, 40 namaz alarmının hepsi kalır",
              trimmed.count == NotificationManager.notificationBudget
              && trimmed.filter { $0.identifier.hasPrefix("prayer_") }.count == 40)

        // T31: Hatırlatma saatleri her planlamada aynı (arka plan yenilemesi silmesin).
        defaults.set(true, forKey: NotificationManager.ayahEnabledKey)
        func reminderTimes() -> [String: DateComponents] {
            var map: [String: DateComponents] = [:]
            for r in nm.buildRequests(coordinate: istanbul, timeZone: istanbulTZ) where r.identifier.hasPrefix("ayah_") || r.identifier.hasPrefix("zikir_") || r.identifier.hasPrefix("quran_") {
                map[r.identifier] = (r.trigger as? UNCalendarNotificationTrigger)?.dateComponents
            }
            return map
        }
        let first = reminderTimes(), second = reminderTimes()
        check("T31", "Hatırlatma saatleri tekrar planlamada değişmiyor", !first.isEmpty && first == second, "adet=\(first.count)")

        // T32: Vakit hesaplanamıyorsa "alarmlar duracak" uyarısı da yok.
        for name in NotificationManager.prayerNames {
            defaults.set(true, forKey: NotificationManager.prayerEnabledKey(name))
        }
        let polarIDs = nm.buildRequests(coordinate: CLLocationCoordinate2D(latitude: 89.0, longitude: 0), timeZone: TimeZone(identifier: "UTC")!).map(\.identifier)
        check("T32", "Alarm kurulamayan konumda güvenlik uyarısı yok",
              !polarIDs.contains { $0.hasPrefix("prayer_") } ? !polarIDs.contains("keepalive_0") : true)

        // T33: Arka arkaya iki planlama isteği: ikisinin de "bitti" bildirimi gelir.
        var done = 0
        nm.rescheduleAll(coordinate: istanbul, timeZone: istanbulTZ) { done += 1 }
        nm.rescheduleAll(coordinate: istanbul, timeZone: istanbulTZ) { done += 1 }
        let deadline = Date().addingTimeInterval(20)
        while done < 2 && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        }
        check("T33", "Birleştirilen planlama isteklerinin hepsi tamamlanıyor (arka plan görevi kapanır)", done == 2, "tamamlanan=\(done)/2")
    }

    // MARK: - Widget

    private static func widgetTests() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = istanbulTZ
        let start = cal.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 12))!
        let days = PrayerCalculation.upcomingDays(7, coordinate: istanbul, timeZone: istanbulTZ, from: start)
        let snap = PrayerWidgetData.Snapshot(cityName: "İstanbul", updatedAt: start, timeZoneID: "Europe/Istanbul", days: days)

        // Yatsı'dan 10 dk sonra: sıradaki "Yarın İmsak", liste hâlâ bugün.
        let afterIsha = days[0].times[5].time.addingTimeInterval(600)
        let steps = PrayerWidgetData.timelineSteps(from: snap, now: afterIsha)
        check("T16", "Widget: Yatsı sonrası \"Yarın İmsak\" ve bugünün listesi",
              steps.first?.nextName == "Yarın İmsak" && steps.first?.today.first?.time == days[0].times[0].time)

        let midnight = steps.first { $0.date == days[1].dayStart }
        check("T17", "Widget: gece yarısı yeni güne geçiyor", midnight?.nextName == "İmsak" && midnight?.today.first?.time == days[1].times[0].time)

        // Uygulama 3 gün açılmadı: widget yine doğru günü gösterir.
        let threeDaysLater = days[3].dayStart.addingTimeInterval(13 * 3600)
        let later = PrayerWidgetData.timelineSteps(from: snap, now: threeDaysLater)
        check("T18", "Widget: uygulama 3 gün açılmasa da doğru gün",
              later.first?.today.first?.time == days[3].times[0].time && (later.first?.nextDate ?? .distantPast) > threeDaysLater)

        let increasing = zip(steps, steps.dropFirst()).allSatisfy { $0.date < $1.date }
        check("T19", "Widget: adımlar zamana göre sıralı", increasing && !steps.isEmpty)

        let expired = PrayerWidgetData.timelineSteps(from: snap, now: start.addingTimeInterval(30 * 86400))
        check("T20", "Widget: veri bitince boş (\"uygulamayı aç\" gösterilir)", expired.isEmpty)

        PrayerWidgetData.save(cityName: "TestŞehir", timeZone: istanbulTZ, days: days)
        let loaded = PrayerWidgetData.load()
        // T34: Aynı veri tekrar kaydedilince dosya değişmez (widget boşuna yenilenmez).
        PrayerWidgetData.save(cityName: "TestŞehir", timeZone: istanbulTZ, days: days)
        check("T34", "Değişmeyen widget verisi tekrar yazılmıyor", PrayerWidgetData.load()?.updatedAt == loaded?.updatedAt)
        check("T21", "Widget verisi App Group'a yazılıp okunuyor",
              loaded?.cityName == "TestŞehir" && loaded?.timeZoneID == "Europe/Istanbul" && loaded?.days.count == 7)

        let previousTheme = PrayerWidgetData.storedDarkTheme()
        PrayerWidgetData.saveDarkTheme(true)
        let t1 = PrayerWidgetData.storedDarkTheme()
        PrayerWidgetData.saveDarkTheme(false)
        let t2 = PrayerWidgetData.storedDarkTheme()
        if let previousTheme { PrayerWidgetData.saveDarkTheme(previousTheme) }
        check("T22", "Widget tema tercihi paylaşılıyor", t1 == true && t2 == false)

        // Gerçek veriyi geri yaz (test şehri widget'ta kalmasın).
        BackgroundRefresh.refreshWidgetData()
    }

    // MARK: - Kıble

    private static func qiblaTests() {
        let bearing = QiblaViewModel.calculateBearing(from: istanbul)
        check("T23", "Kıble açısı İstanbul ≈ 151.6°", abs(bearing - 151.6) < 0.6, String(format: "%.2f°", bearing))

        let vm = QiblaViewModel()
        vm.setBearing(from: istanbul)
        vm.applyHeading(359)
        let a1 = vm.arrowAngle
        vm.applyHeading(1)
        let a2 = vm.arrowAngle
        check("T24", "Kıble oku kuzeyden geçerken tam tur atmıyor", abs(a2 - a1) < 5, "değişim=\(a2 - a1)°")
    }

    // MARK: - İçerik ve ayarlar

    private static func contentTests() {
        check("T25", "Meal baskıları sabit (tr.vakfi / en.sahih / de.bubenheim / ar yok)",
              QuranAPI.mealEdition(for: .turkish) == "tr.vakfi"
              && QuranAPI.mealEdition(for: .english) == "en.sahih"
              && QuranAPI.mealEdition(for: .german) == "de.bubenheim"
              && QuranAPI.mealEdition(for: .arabic) == nil)

        check("T26", "App Store ID yokken yorum bağlantısı açılmıyor (Apple penceresi kullanılır)",
              ReviewManager.appStoreID.isEmpty ? ReviewManager.writeReviewURL == nil : ReviewManager.writeReviewURL != nil)

        let newKeys = ["common_ok", "home_calc_failed", "notif_keepalive_title", "notif_keepalive_body",
                       "settings_notif_denied", "settings_open_ios_settings", "settings_ad_privacy",
                       "qibla_calibrate", "tts_missing_title", "tts_missing_body", "mosque_err_search",
                       "settings_prayer_notifs_footer2", "settings_manual_toggle", "settings_manual_toggle_sub",
                       "settings_auto_location", "contact_copied_title", "contact_copied_body",
                       "qibla_no_compass_hint", "mosque_directions", "quran_no_match", "common_clear",
                       "primer_title", "primer_yes", "primer_later", "primer_body", "home_bell_hint",
                       "home_alarm_on", "home_alarm_off", "home_alarm_denied_body",
                       "settings_religious_reminder", "religious_night_title", "religious_night_body",
                       "religious_day_title", "religious_day_body", "ramadan_to_iftar", "ramadan_to_sahur",
                       "home_prayed_count", "home_row_hint", "home_prayed_on", "home_prayed_off",
                       "sahur_title", "sahur_body", "tracking_title", "tracking_today", "tracking_streak",
                       "tracking_kaza", "tracking_kaza_footer", "tracking_last7", "tracking_not_yet",
                       "imsakiye_title", "imsakiye_footer", "settings_sahur", "settings_sahur_before",
                       "settings_ramadan", "settings_sahur_footer", "imsakiye_day_n",
                       "recitation_error", "recitation_error_title", "recitation_from_ayah", "recitation_reciter",
                       "recitation_now", "recitation_pause", "sources_title", "sources_note",
                       "zikir_reset_confirm_title", "zikir_reset_confirm_body", "zikir_mode_tesbihat",
                       "tesbih_subhanallah", "tesbih_elhamdulillah", "tesbih_allahuekber", "tesbih_step", "privacy_read_web", "lock_widget_name", "lock_widget_desc", "kerahat_now_title", "kerahat_israk", "kerahat_istiva", "kerahat_isfirar", "settings_kerahat", "settings_kerahat_footer", "siri_no_location", "siri_no_times", "siri_next_answer", "siri_remaining_hm", "siri_remaining_m", "siri_kerahat_now", "siri_kerahat_next", "siri_kerahat_none", "qibla_kaaba", "qibla_you", "qibla_map_info", "qibla_map_hint", "qibla_map_near", "qibla_map_whole", "qibla_map_title", "qibla_map_button", "home_alarm_toast_on", "home_alarm_toast_off", "imsakiye_ramadan_year", "settings_kerahat_page", "kerahat_today", "common_on", "common_off", "qibla_map_north", "qibla_map_hint_north", "prayer_sabah", "prayer_vitir", "qibla_map_info2", "watch_open_phone", "settings_adjust_footer_other", "tracking_marked", "tracking_unmarked", "common_undo", "settings_current_place", "home_time_left", "settings_adjust_footer_abroad", "duas_jump", "watch_qibla_hint", "audio_download", "audio_downloaded", "audio_downloading", "audio_delete_title", "audio_delete", "audio_delete_body", "audio_download_error", "audio_download_error_title", "audio_storage_title", "audio_storage_size", "audio_delete_all", "method_title", "method_diyanet", "method_isna", "method_mwl", "method_ummAlQura", "method_footer"]
        let missing = newKeys.filter { key in
            guard let e = LocalizationStrings.table[key] else { return true }
            return e[.english] == nil || e[.arabic] == nil || e[.german] == nil
        }
        check("T27", "Yeni metinlerin en/ar/de çevirileri var", missing.isEmpty, missing.joined(separator: ","))

        // T57: Gizlilik metni 4 dilde tam; web bağlantısı ve e-posta doğru.
        do {
            let langs: [AppLanguage] = [.turkish, .english, .german, .arabic]
            let incomplete = PrivacyPolicyText.sections.enumerated().filter { _, sec in
                langs.contains { (sec.title[$0] ?? "").isEmpty || (sec.body[$0] ?? "").isEmpty }
            }.map { "\($0.offset + 1)" }
            let urlOK = PrivacyPolicyText.webURL.absoluteString == "https://kocaksefa.com/safa-app/#gizlilik"
            let mailOK = PrivacyPolicyText.contactEmail == "info@kocaksefa.com"
                && PrivacyPolicyText.sections.contains { ($0.body[.turkish] ?? "").contains("info@kocaksefa.com") }
            check("T57", "Gizlilik metni 4 dilde, web linki + e-posta doğru",
                  incomplete.isEmpty && urlOK && mailOK && PrivacyPolicyText.sections.count == 9,
                  "eksik:\(incomplete) url:\(urlOK) mail:\(mailOK)")
        }

        // T58: Firebase kaldırıldı; gizlilik metninde de geçmiyor.
        do {
            let noSDK = NSClassFromString("FIRApp") == nil
            let noPlist = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") == nil
            let noText = !PrivacyPolicyText.sections.contains { sec in sec.body.values.contains { $0.contains("Firebase") } }
            check("T58", "Firebase uygulamada yok, gizlilik metninde geçmiyor", noSDK && noPlist && noText,
                  "sdk:\(noSDK) plist:\(noPlist) metin:\(noText)")
        }

        // T59: Yazı büyütme: yazılar metin boyutuna göre büyür ama sınırı aşmaz.
        do {
            let small = AppTheme.scaled(15), big = AppTheme.scaled(40)
            check("T59", "Yazı boyutu iPhone ayarına uyar, büyük yazılar en fazla 1,25 kat",
                  small >= 15 * 0.7 && small <= 15 * 1.6 && big <= 40 * 1.25,
                  "15→\(small) 40→\(big)")
        }

        // T60: Kerahat vakitleri: güneş doğuşu +45, öğleden önce 45, akşamdan önce 45 dk.
        do {
            let base = Date(timeIntervalSince1970: 1_800_000_000)
            let ws = KerahatTimes.windows(sunrise: base, dhuhr: base.addingTimeInterval(5 * 3600), maghrib: base.addingTimeInterval(11 * 3600))
            let ok = ws.count == 3
                && ws[0].end.timeIntervalSince(ws[0].start) == 2700 && ws[0].start == base
                && ws[1].end == base.addingTimeInterval(5 * 3600) && ws[1].contains(base.addingTimeInterval(5 * 3600 - 60))
                && ws[1].start == base.addingTimeInterval(5 * 3600 - 600)
                && !ws[1].contains(base.addingTimeInterval(5 * 3600))
                && ws[2].start == base.addingTimeInterval(11 * 3600 - 2700)
            let ankara = CLLocationCoordinate2D(latitude: 39.9334, longitude: 32.8597)
            let tz = TimeZone(identifier: "Europe/Istanbul")!
            let real = PrayerCalculation.times(on: base, coordinate: ankara, timeZone: tz)
            let inIsrak = real.map { KerahatTimes.current(now: $0.sunrise.addingTimeInterval(600), coordinate: ankara, timeZone: tz)?.kind == .israk } ?? false
            let outside = real.map { KerahatTimes.current(now: $0.sunrise.addingTimeInterval(3 * 3600), coordinate: ankara, timeZone: tz) == nil } ?? false
            check("T60", "Kerahat: sabah/akşam 45 dk, öğle (istiva) 10 dk; doğuştan 10 dk sonra işrak, 3 saat sonra kerahat yok", ok && inIsrak && outside)
        }

        // T61: Siri cevapları: kayıtlı konumla sıradaki namaz ve kerahat cümlesi üretilir.
        do {
            let d = UserDefaults.standard
            let keys = ["lastKnownLatitude", "lastKnownLongitude", "lastKnownTimeZoneID"]
            let backup = keys.map { ($0, d.object(forKey: $0)) }
            d.set(39.9334, forKey: "lastKnownLatitude"); d.set(32.8597, forKey: "lastKnownLongitude"); d.set("Europe/Istanbul", forKey: "lastKnownTimeZoneID")
            let next = SiriPrayerInfo.nextPrayerAnswer()
            let ker = SiriPrayerInfo.kerahatAnswer()
            backup.forEach { if let v = $0.1 { d.set(v, forKey: $0.0) } else { d.removeObject(forKey: $0.0) } }
            let names = ["İmsak", "Güneş", "Öğle", "İkindi", "Akşam", "Yatsı", "Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha"]
            let nameOK = names.contains { next.contains(LocalizationManager.shared.x($0)) || next.contains($0) }
            check("T61", "Siri: sıradaki namaz ve kerahat cevabı üretiliyor", nameOK && next.contains(":") && !ker.isEmpty && !ker.contains("%"),
                  "\(next) | \(ker)")
        }

        // T62: Kıble haritası: Ankara'dan Kâbe ~2.200 km; İstanbul kıblesi ~151°.
        do {
            let ankaraKm = QiblaMapView.distanceKm(from: CLLocationCoordinate2D(latitude: 39.9334, longitude: 32.8597))
            let istBearing = QiblaViewModel.calculateBearing(from: CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784))
            check("T62", "Kıble haritası: Ankara–Kâbe 2.100–2.300 km, İstanbul kıblesi 150–153°",
                  (2100...2300).contains(ankaraKm) && (150...153).contains(istBearing), "km:\(Int(ankaraKm)) açı:\(istBearing)")
        }

        // T63: Cami süzgeci: mağaza/restoran çıkmaz; adında cami geçen yerler kalır.
        do {
            let keep = ["Ashabi Kehf Camii", "Islamisches Kulturzentrum der Bosniaken", "Şehitlik Moschee", "Blue Mosque", "Kocatepe Camii", "Fatih Mescidi", "DITIB Zentralmoschee", "مسجد النور"]
            let drop = ["Intimissimi", "Hunkemöller", "New Yorker", "Princesse tam.tam", "Love Stories"]
            let keepOK = keep.allSatisfy { MosqueSearchManager.isMosque(name: $0, category: nil) }
            let dropOK = drop.allSatisfy { !MosqueSearchManager.isMosque(name: $0, category: .store) && !MosqueSearchManager.isMosque(name: $0, category: nil) }
            let shopNamedCami = !MosqueSearchManager.isMosque(name: "Cami Pide Salonu", category: .restaurant)
            check("T63", "Cami listesi: mağaza/restoran çıkmıyor, camiler kalıyor", keepOK && dropOK && shopNamedCami)
        }

        // T64: Alarm zili yazısı + imsakiye başlığı.
        do {
            let on = HomeView.alarmToastText(enabled: true, prayer: "Akşam")
            let off = HomeView.alarmToastText(enabled: false, prayer: "Akşam")
            check("T64", "Zil yazısı: \"Akşam alarmı açıldı/kapatıldı\" (dile göre)", on.contains("Akşam") && off.contains("Akşam") && on != off && !on.contains("%"),
                  "\(on) | \(off)")
        }

        // T65: Saat dilimi uyuşmazlığında çökme yok (telefon İstanbul saatinde, konum Sidney/Tokyo/Los Angeles).
        do {
            let ist = TimeZone(identifier: "Europe/Istanbul")!
            let places = [CLLocationCoordinate2D(latitude: -33.917, longitude: 151.099),
                          CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503),
                          CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437)]
            var ok = true
            for c in places {
                let vm = PrayerTimeViewModel()
                vm.start(coordinate: c, timeZone: ist)      // eskiden burada sonsuz döngü → çökme
                ok = ok && vm.prayerTimes != nil && vm.nextPrayerName != "-"
                vm.start(coordinate: c, timeZone: TimeZone(identifier: "Australia/Sydney")!)
                ok = ok && vm.prayerTimes != nil
            }
            check("T65", "Saat dilimi farklı konumda (Sidney/Tokyo/LA, telefon İstanbul) uygulama çökmüyor", ok)
        }

        // T66: Diyanet resmi tablosuyla dakika dakika karşılaştırma (İstanbul 7 gün, Erzurum, Ankara 6 gün).
        do {
            let ist = TimeZone(identifier: "Europe/Istanbul")!
            let refs: [(Double, Double, String, String)] = [
                (41.0082, 28.9784, "2026-10-21", "05:50 07:15 12:54 15:53 18:23 19:42"),
                (41.0082, 28.9784, "2026-10-22", "05:51 07:16 12:54 15:51 18:21 19:41"),
                (41.0082, 28.9784, "2026-10-23", "05:52 07:17 12:53 15:50 18:20 19:40"),
                (41.0082, 28.9784, "2026-10-24", "05:53 07:18 12:53 15:49 18:19 19:38"),
                (41.0082, 28.9784, "2026-10-25", "05:54 07:19 12:53 15:48 18:17 19:37"),
                (41.0082, 28.9784, "2026-10-26", "05:55 07:21 12:53 15:47 18:16 19:36"),
                (41.0082, 28.9784, "2026-10-27", "05:56 07:22 12:53 15:46 18:14 19:34"),
                (39.9043, 41.2679, "2026-10-21", "05:01 06:24 12:05 15:05 17:35 18:53"),
                (39.9334, 32.8597, "2026-10-21", "05:35 06:58 12:38 15:39 18:09 19:27"),
                (39.9334, 32.8597, "2027-01-10", "06:34 08:03 13:01 15:27 17:49 19:13"),
                (39.9334, 32.8597, "2027-03-20", "05:22 06:46 13:01 16:25 19:07 20:25"),
                (39.9334, 32.8597, "2027-06-21", "03:17 05:13 12:55 16:53 20:28 22:15"),
                (39.9334, 32.8597, "2027-08-10", "04:11 05:48 12:59 16:49 20:00 21:31"),
                (39.9334, 32.8597, "2027-12-10", "06:22 07:52 12:46 15:09 17:30 18:55")
            ]
            let df = DateFormatter(); df.timeZone = ist; df.dateFormat = "yyyy-MM-dd HH:mm"
            let hm = DateFormatter(); hm.timeZone = ist; hm.dateFormat = "HH:mm"
            // Kullanıcının dakika ince ayarı testi etkilemesin.
            let adjKeys = ["fajr", "dhuhr", "asr", "maghrib", "isha"].map { "prayer_manual_adjust_\($0)" }
            let adjBackup = adjKeys.map { ($0, UserDefaults.standard.object(forKey: $0)) }
                + [(PrayerCalculation.methodKey, UserDefaults.standard.object(forKey: PrayerCalculation.methodKey))]
            adjKeys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
            UserDefaults.standard.removeObject(forKey: PrayerCalculation.methodKey)   // test her zaman Diyanet ile
            var exact = 0, total = 0, worst = 0.0, misses: [String] = []
            for (lat, lon, day, line) in refs {
                guard let noon = df.date(from: day + " 12:00"),
                      let t = PrayerCalculation.times(on: noon, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon), timeZone: ist) else { continue }
                let ours = [t.fajr, t.sunrise, t.dhuhr, t.asr, t.maghrib, t.isha]
                for (i, ref) in line.split(separator: " ").enumerated() {
                    guard let r = df.date(from: day + " " + ref) else { continue }
                    let diff = abs(ours[i].timeIntervalSince(r)) / 60
                    total += 1; worst = max(worst, diff)
                    if diff < 0.5 { exact += 1 } else { misses.append("\(day) #\(i) \(hm.string(from: ours[i]))≠\(ref)") }
                }
            }
            adjBackup.forEach { if let v = $0.1 { UserDefaults.standard.set(v, forKey: $0.0) } }
            check("T66", "Diyanet tablosuyla: vakitlerin ≥%90'ı tam dakika, hiçbiri 1 dk'dan fazla değil",
                  total == 84 && Double(exact) / Double(total) >= 0.9 && worst <= 1,
                  "tam \(exact)/\(total), en kötü \(Int(worst)) dk \(misses.prefix(4))")
        }

        // T67: Sade okunuş + "Sabah" adı + Vitir kazası.
        do {
            let a = QuranAPI.simpleTransliteration("Bismi-llâhi-rraḥmâni-rraḥîm.")
            let b = QuranAPI.simpleTransliteration("İhdine-ṣṣirâṭa-lmüsteḳîm. na`büdü")
            let names = PrayerTracker.kazaNames
            check("T67", "Okunuş sade (Bismillâhirrahmânirrahîm), sabah namazı \"Sabah\", kazada Vitir var",
                  a == "Bismillâhirrahmânirrahîm." && b == "İhdinessirâtalmüstekîm. nabüdü"
                  && names.contains("Vitir") && names.count == 6
                  && PrayerTracker.namazName("İmsak") == LocalizationManager.shared.t("prayer_sabah", fallback: "Sabah"), "\(a) | \(b)")
        }

        // T68: Yer adı: Türkiye "İl İlçe", yurt dışı "Semt, Bölge".
        do {
            let tr = PlaceName.format(country: "TR", locality: "Fatih", subLocality: nil, subAdministrativeArea: "Fatih", administrativeArea: "İstanbul")
            let ny = PlaceName.format(country: "US", locality: "Brooklyn", subLocality: nil, subAdministrativeArea: "Kings County", administrativeArea: "NY")
            let au = PlaceName.format(country: "AU", locality: "Lakemba", subLocality: nil, subAdministrativeArea: "Canterbury-Bankstown Council", administrativeArea: "NSW")
            let se = PlaceName.format(country: "SE", locality: "Stockholm", subLocality: nil, subAdministrativeArea: nil, administrativeArea: "Stockholm")
            check("T68", "Yer adı: İstanbul Fatih / Brooklyn, NY / Lakemba, NSW / Stockholm",
                  tr == "İstanbul Fatih" && ny == "Brooklyn, NY" && au == "Lakemba, NSW" && se == "Stockholm",
                  "\(tr ?? "-") | \(ny ?? "-") | \(au ?? "-") | \(se ?? "-")")
        }

        // T69: Hesaplama yöntemi: varsayılan Diyanet; ISNA seçilince New York İmsak'ı değişir; geri alınır.
        do {
            let d = UserDefaults.standard
            let backup = d.object(forKey: PrayerCalculation.methodKey)
            d.removeObject(forKey: PrayerCalculation.methodKey)
            let ny = CLLocationCoordinate2D(latitude: 40.6782, longitude: -73.9442)
            let tz = TimeZone(identifier: "America/New_York")!
            let def = PrayerCalculation.selectedMethod == .diyanet
            let a = PrayerCalculation.times(on: Date(), coordinate: ny, timeZone: tz)
            d.set(PrayerCalculation.Method.isna.rawValue, forKey: PrayerCalculation.methodKey)
            let b = PrayerCalculation.times(on: Date(), coordinate: ny, timeZone: tz)
            if let backup { d.set(backup, forKey: PrayerCalculation.methodKey) } else { d.removeObject(forKey: PrayerCalculation.methodKey) }
            let later = (b?.fajr ?? .distantPast) > (a?.fajr ?? .distantFuture)
            check("T69", "Hesaplama yöntemi: varsayılan Diyanet, ISNA'da İmsak daha geç", def && later)
        }

        // T70: Saat/mesafe biçimi: telefonun 12/24 saat ve mil/km ayarına uyar.
        do {
            let tz = TimeZone(identifier: "Europe/Istanbul")!
            let d = Date(timeIntervalSince1970: 1_792_600_200)   // 21.10.2026 19:30 İstanbul
            let t = DisplayFormat.time(d, timeZone: tz, locale: Locale(identifier: "en_US"))
            let timeOK = DisplayFormat.uses12Hour ? (t.contains("7:30") && t.uppercased().contains("PM")) : t == "19:30"
            let m = DisplayFormat.distance(meters: 2300)
            let distOK = m == (DisplayFormat.usesMiles ? DisplayFormat.oneDecimal(1.4) + " mi" : DisplayFormat.oneDecimal(2.3) + " km")
            let longOK = DisplayFormat.longDistance(km: 2400).hasSuffix(DisplayFormat.usesMiles ? "mi" : "km")
            check("T70", "Saat ve mesafe telefon ayarına göre (12/24 saat, mil/km)", timeOK && distOK && longOK,
                  "\(t) | \(m) | 12h:\(DisplayFormat.uses12Hour) mil:\(DisplayFormat.usesMiles)")
        }

        // T71: Çevrimdışı hafız sesi: indirilen ayet telefondan çalar, silinince internete döner.
        do {
            let n = 6236   // Nâs suresinin son ayeti (testte sahte dosya)
            let store = QuranAudioStore.shared
            let hadBefore = QuranAudioStore.hasLocal(n)
            let local = QuranAudioStore.localURL(globalAyahNumber: n)
            if !hadBefore { FileManager.default.createFile(atPath: local.path, contents: Data([0x49, 0x44, 0x33])) }
            let usesLocal = RecitationPlayer.audioURL(globalAyahNumber: n)?.isFileURL == true
            let downloaded = store.isDownloaded([n])
            let backupExcluded = (try? QuranAudioStore.folder.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup) == true
            if !hadBefore { store.delete([n]) }
            let backToRemote = hadBefore || RecitationPlayer.audioURL(globalAyahNumber: n)?.isFileURL == false
            check("T71", "Çevrimdışı ses: indirilen ayet telefondan çalar, silinince internetten; klasör iCloud yedeğinde değil",
                  usesLocal && downloaded && backToRemote && backupExcluded && !store.isDownloaded([]))
        }

        // T72: Test sürümü simülatörde sessiz; gerçek telefonda ses açık.
        do {
            #if targetEnvironment(simulator)
            let expected = true
            #else
            let expected = false
            #endif
            check("T72", "Simülatörde test sesi kapalı, telefonda açık", DebugMute.isOn == expected)
        }

        // T73: Apple Watch'a giden bilgi: konum, saat dilimi, dil, hesaplama yöntemi, ince ayarlar.
        do {
            let ctx = WatchSync.context()
            let keys = ["lat", "lon", "tz", "city", "lang", "method", "adj_fajr", "adj_asr", "adj_isha"]
            let watchEmbedded = Bundle.main.bundleURL.appendingPathComponent("Watch/SafaWatch.app").path
            // Telefon testi saat uygulaması olmadan derlenir (ücretsiz hesap saat istemeden imzalamıyor).
            #if targetEnvironment(simulator)
            let embeddedOK = FileManager.default.fileExists(atPath: watchEmbedded)
            #else
            let embeddedOK = true
            #endif
            check("T73", "Apple Watch: iPhone saate konum/dil/yöntem gönderir; saat uygulaması paketin içinde (simülatör)",
                  keys.allSatisfy { ctx[$0] != nil } && embeddedOK,
                  "eksik: \(keys.filter { ctx[$0] == nil })")
        }

        // T74: Saat dilimi tahmini: şehir adı/saat dilimi alınamazsa telefon saati değil, boylam kullanılır.
        do {
            let ist = TimeZone(identifier: "Europe/Istanbul")!
            let ny = LocationManager.estimatedTimeZone(longitude: -73.94, device: ist).secondsFromGMT()
            let tr = LocationManager.estimatedTimeZone(longitude: 28.97, device: ist).identifier
            let syd = LocationManager.estimatedTimeZone(longitude: 151.1, device: ist).secondsFromGMT()
            check("T74", "Saat dilimi tahmini: New York -5, İstanbul aynen, Sidney +10 (telefon İstanbul saatinde)",
                  ny == -5 * 3600 && tr == "Europe/Istanbul" && syd == 10 * 3600, "ny:\(ny/3600) tr:\(tr) syd:\(syd/3600)")
        }

        // T75: Dualar tam: Kunut 1, Âyetü'l-Kürsî, Rabbişrahlî, Âmenerrasûlü uzun metin + doğru ayetler.
        do {
            let duas = PrayerDuasView().duas
            func dua(_ prefix: String) -> PrayerDua? { duas.first { $0.title.hasPrefix(prefix) } }
            let kunut = dua("Kunut Duası 1"), kursi = dua("Âyetü'l-Kürsî"), sharh = dua("Rabbişrahlî"), amana = dua("Âmenerrasûlü")
            let ok = (kunut?.okunus.contains("yefcürük") ?? false)
                && (kursi?.okunus.contains("aliyyül azîm") ?? false) && kursi?.quranAyahs == [262]
                && (sharh?.okunus.contains("kavlî") ?? false) && sharh?.quranAyahs == [2373, 2374, 2375, 2376]
                && (amana?.okunus.contains("kâfirîn") ?? false) && amana?.quranAyahs == [292, 293]
                && !(ReligiousDays.upcoming(from: Date(timeIntervalSince1970: 1_790_000_000)).contains { ($0.name.hasPrefix("Ramazan Bayramı") || $0.name == "Kadir Gecesi") && $0.note == "Yaklaşık tarih" && $0.date < Date(timeIntervalSince1970: 1_800_000_000) })
            check("T75", "Dualar tam metin (Kunut 1, Kürsî, Rabbişrahlî, Âmenerrasûlü); Diyanet tarihlerinde 'Yaklaşık' yok", ok)
        }

        // T76: 4. tur düzeltmeleri: kaza değeri her okumada güncel; yurt dışı/Türkiye açıklama ayrımı; uygulama adı Safa.
        do {
            let backup = PrayerTracker.kazaCount("Vitir")
            PrayerTracker.setKazaCount(4, for: "Vitir")
            let a = PrayerTracker.kazaCount("Vitir")
            PrayerTracker.setKazaCount(a + 1, for: "Vitir")      // "+" her seferinde güncel değeri okur
            let b = PrayerTracker.kazaCount("Vitir")
            PrayerTracker.setKazaCount(backup, for: "Vitir")
            let d = UserDefaults.standard
            let tzBackup = d.object(forKey: "lastKnownTimeZoneID")
            d.set("Europe/Berlin", forKey: "lastKnownTimeZoneID"); let abroad = !SettingsView.locationIsInTurkey
            d.set("Europe/Istanbul", forKey: "lastKnownTimeZoneID"); let home = SettingsView.locationIsInTurkey
            if let tzBackup { d.set(tzBackup, forKey: "lastKnownTimeZoneID") } else { d.removeObject(forKey: "lastKnownTimeZoneID") }
            check("T76", "Kaza +1 güncel değerden; 'en fazla 1 dk' yazısı sadece Türkiye'de", a == 4 && b == 5 && abroad && home)
        }

        // T35: Çift Besmele kaldırılıyor (Fâtiha ve Tevbe hariç).
        let b = QuranAPI.basmala
        let bakara = QuranAPI.removingLeadingBasmala([QuranAyah(number: 8, text: b + " الٓمٓ", numberInSurah: 1)], surah: 2)
        let fatiha = QuranAPI.removingLeadingBasmala([QuranAyah(number: 1, text: "\u{FEFF}" + b, numberInSurah: 1)], surah: 1)
        check("T35", "Sure başındaki çift Besmele kaldırılıyor, Fâtiha'da kalıyor",
              bakara.first?.text == "الٓمٓ" && fatiha.first?.text.contains(b) == true)

        // T36: Türkçe harflere duyarlı arama.
        check("T36", "Arama: ist→İstanbul, IST→İstanbul, yasin→Yâsîn, Yasın→Yâsîn, ali imran→Âl-i İmrân",
              "İstanbul".matchesSearch("ist") && "İstanbul".matchesSearch("IST")
              && "Yâsîn".matchesSearch("yasin") && "Yâsîn".matchesSearch("Yasın")
              && "Âl-i İmrân (İmran Ailesi)".matchesSearch("ali imran") && !"Ankara".matchesSearch("ist"))

        // T37: Almanca arayüzde sure adı İngilizce çeviri değil okunuş adı.
        let savedLanguage = LocalizationManager.shared.language
        LocalizationManager.shared.language = .german
        let sample = QuranSurahSummary(number: 1, name: "سُورَةُ ٱلْفَاتِحَةِ", englishName: "Al-Faatiha", englishNameTranslation: "The Opening", numberOfAyahs: 7, revelationType: "Meccan")
        let germanTitle = SurahNames.title(for: sample)
        LocalizationManager.shared.language = .turkish
        let turkishTitle = SurahNames.title(for: sample)
        LocalizationManager.shared.language = savedLanguage
        check("T37", "Sure adı dile göre (de: Al-Faatiha, tr: Fâtiha (Açılış))",
              germanTitle == "Al-Faatiha" && turkishTitle == "Fâtiha (Açılış)", "\(germanTitle) / \(turkishTitle)")

        check("T38", "Yakındaki cami sınırı 15 km (1770 km'lik sonuç elenir)", MosqueSearchManager.maxDistanceMeters == 15_000)

        // T45: "Kıldım" kaydı ve seri (ayarlar test sonunda tam geri yüklenir).
        var tcal = Calendar(identifier: .gregorian); tcal.timeZone = istanbulTZ
        let tday = tcal.date(from: DateComponents(year: 2030, month: 1, day: 10, hour: 12))!
        let k0 = PrayerTracker.dayKey(tday, timeZone: istanbulTZ)
        let k1 = PrayerTracker.dayKey(tcal.date(byAdding: .day, value: -1, to: tday)!, timeZone: istanbulTZ)
        for n in NotificationManager.prayerNames { PrayerTracker.setPrayed(true, name: n, dayKey: k1) }
        PrayerTracker.setPrayed(true, name: "Öğle", dayKey: k0)
        let partialToday = PrayerTracker.prayedCount(dayKey: k0) == 1
        let streakYesterday = PrayerTracker.streak(today: tday, timeZone: istanbulTZ) == 1
        for n in NotificationManager.prayerNames { PrayerTracker.setPrayed(true, name: n, dayKey: k0) }
        let streakTwo = PrayerTracker.streak(today: tday, timeZone: istanbulTZ) == 2
        PrayerTracker.setPrayed(false, name: "Öğle", dayKey: k0)
        let unmarked = !PrayerTracker.isPrayed("Öğle", dayKey: k0)
        check("T45", "Kıldım kaydı: sayım, işaret kaldırma ve seri (dün tam → 1, bugün de tam → 2)",
              partialToday && streakYesterday && streakTwo && unmarked && k0 == "2030-01-10")

        // T47: Ramazan günleri (Hicri 1448: yaklaşık 8 Şubat – 9 Mart 2027).
        var rcal = Calendar(identifier: .gregorian); rcal.timeZone = istanbulTZ
        let midRamadan = rcal.date(from: DateComponents(year: 2027, month: 2, day: 20, hour: 12))!
        let outside = rcal.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 12))!
        let rDays = RamadanInfo.ramadanDays(around: outside, timeZone: istanbulTZ)
        let firstKey = rDays.first.map { PrayerTracker.dayKey($0.addingTimeInterval(43_200), timeZone: istanbulTZ) } ?? "-"
        check("T47", "Ramazan: 20 Şubat 2027 Ramazan içinde, 21 Ekim 2026 değil; sıradaki Ramazan 8 Şubat 2027'de başlıyor",
              RamadanInfo.dayOfRamadan(midRamadan, timeZone: istanbulTZ) != nil
              && RamadanInfo.dayOfRamadan(outside, timeZone: istanbulTZ) == nil
              && (29...30).contains(rDays.count) && firstKey == "2027-02-08",
              "ilk gün=\(firstKey), gün sayısı=\(rDays.count)")

        // T48: Ana sayfa sayacı: Ramazan'da öğlen → iftar (akşam), gece → sahur (ertesi imsak); Ramazan dışında yok.
        let noon = RamadanInfo.fastingTarget(now: midRamadan, coordinate: istanbul, timeZone: istanbulTZ)
        let night = RamadanInfo.fastingTarget(now: midRamadan.addingTimeInterval(10 * 3600), coordinate: istanbul, timeZone: istanbulTZ)
        let maghrib = PrayerCalculation.times(on: midRamadan, coordinate: istanbul, timeZone: istanbulTZ)?.maghrib
        let nextFajr = PrayerCalculation.times(on: midRamadan.addingTimeInterval(86_400), coordinate: istanbul, timeZone: istanbulTZ)?.fajr
        check("T48", "Ramazan sayacı: öğlen iftara, gece 22:00'de sahura sayar; Ramazan dışında sayaç yok",
              noon == maghrib.map { .iftar($0) } && night == nextFajr.map { .sahur($0) }
              && RamadanInfo.fastingTarget(now: outside, coordinate: istanbul, timeZone: istanbulTZ) == nil)

        // T49: Sahur alarmı: Ramazan'da 7 gün, İmsak'tan 45 dk önce; kapalıyken yok.
        let sd = UserDefaults.standard
        sd.set(true, forKey: NotificationManager.sahurEnabledKey)
        sd.set(45, forKey: NotificationManager.sahurMinutesKey)
        let sahur = NotificationManager.shared.sahurRequests(coordinate: istanbul, timeZone: istanbulTZ, now: midRamadan)
        let firstFajr = PrayerCalculation.times(on: midRamadan.addingTimeInterval(86_400), coordinate: istanbul, timeZone: istanbulTZ)?.fajr
        let firstFire = (sahur.first?.trigger as? UNCalendarNotificationTrigger)?.dateComponents
        var fcal = Calendar(identifier: .gregorian); fcal.timeZone = istanbulTZ
        let firstFireDate = firstFire.flatMap { c -> Date? in var c2 = c; c2.calendar = fcal; return c2.date }
        let offsetOK = firstFireDate.map { abs(($0.timeIntervalSince(firstFajr ?? $0)) + 45 * 60) < 1.5 } ?? false
        sd.set(false, forKey: NotificationManager.sahurEnabledKey)
        let sahurOff = NotificationManager.shared.sahurRequests(coordinate: istanbul, timeZone: istanbulTZ, now: midRamadan)
        let outsideSahur = { () -> Int in
            sd.set(true, forKey: NotificationManager.sahurEnabledKey)
            return NotificationManager.shared.sahurRequests(coordinate: istanbul, timeZone: istanbulTZ, now: outside).count
        }()
        check("T49", "Sahur alarmı: Ramazan'da İmsak'tan 45 dk önce; kapalıyken ve Ramazan dışında yok",
              sahur.count >= 6 && offsetOK && sahurOff.isEmpty && outsideSahur == 0,
              "adet=\(sahur.count)")

        // T50: Hafız sesi adresleri ve ayet geçişi.
        check("T50", "Hafız sesi: ayet 1 ve 6236 için doğru adres, sınır dışı yok; son ayetten sonra durur",
              RecitationPlayer.remoteURL(globalAyahNumber: 1)?.absoluteString == "https://cdn.islamic.network/quran/audio/128/ar.alafasy/1.mp3"
              && RecitationPlayer.audioURL(globalAyahNumber: 6236) != nil
              && RecitationPlayer.audioURL(globalAyahNumber: 0) == nil
              && RecitationPlayer.audioURL(globalAyahNumber: 6237) == nil
              && RecitationPlayer.nextIndex(after: 0, count: 7) == 1
              && RecitationPlayer.nextIndex(after: 6, count: 7) == nil)

        // T53: Okunuş baskısı dile göre.
        check("T53", "Okunuş: Türkçede Türkçe yazım (tr.transliteration), diğer dillerde İngilizce yazım",
              QuranAPI.transliterationEdition(for: .turkish) == "tr.transliteration"
              && QuranAPI.transliterationEdition(for: .english) == "en.transliteration"
              && QuranAPI.transliterationEdition(for: .german) == "en.transliteration")

        // T55: Tesbihat sırası: 0–32 Sübhanallah, 33–65 Elhamdülillah, 66–99 Allahu Ekber.
        let p0 = Tesbihat.phase(for: 0), p32 = Tesbihat.phase(for: 32), p33 = Tesbihat.phase(for: 33)
        let p65 = Tesbihat.phase(for: 65), p66 = Tesbihat.phase(for: 66), p99 = Tesbihat.phase(for: 99)
        check("T55", "Tesbihat: 33 Sübhanallah → 33 Elhamdülillah → 34 Allahu Ekber, toplam 100",
              p0.index == 0 && p0.done == 0 && p32.index == 0 && p32.done == 32
              && p33.index == 1 && p33.done == 0 && p65.index == 1 && p65.done == 32
              && p66.index == 2 && p66.done == 0 && p66.target == 34 && p99.index == 2 && p99.done == 33
              && Tesbihat.total == 100 && Tesbihat.phases.map(\.target).reduce(0, +) == 100)

        // T56: Kur'an ayeti olan 5 dua hafız sesiyle, geçerli ayet numaralarıyla.
        let quranDuas = PrayerDuasView().duas.filter { !$0.quranAyahs.isEmpty }
        check("T56", "Dualar: 5 Kur'an duasında hafız sesi (Rabbena Atina 2:201=208 …), numaralar geçerli",
              quranDuas.count == 5
              && quranDuas.allSatisfy { $0.quranAyahs.allSatisfy { RecitationPlayer.audioURL(globalAyahNumber: $0) != nil } }
              && quranDuas.first { $0.title == "Rabbena Atina" }?.quranAyahs == [208],
              "adet=\(quranDuas.count)")

        // T52: "Hakkında"daki sürüm, uygulamanın gerçek sürümü.
        let realVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "-"
        check("T52", "Hakkında: sürüm uygulamanın gerçek sürümünü gösteriyor", SettingsView.appVersionText.hasPrefix(realVersion + " ("),
              SettingsView.appVersionText)

        // T46: Kaza sayacı eksiye inmez, toplam doğru.
        PrayerTracker.setKazaCount(3, for: "İmsak")
        PrayerTracker.setKazaCount(-5, for: "Yatsı")
        check("T46", "Kaza sayacı: eksi değer 0 olur, toplam doğru",
              PrayerTracker.kazaCount("Yatsı") == 0 && PrayerTracker.kazaCount("İmsak") == 3 && PrayerTracker.totalKaza >= 3)

        // T40: İlk izin verilişinde 5 vaktin alarmı açılır, hatırlatıcılar kapalı kalır; ikinci kez değişmez.
        let d = UserDefaults.standard
        let keys = NotificationManager.prayerNames.map { NotificationManager.prayerEnabledKey($0) } + ["notif_defaults_applied", NotificationManager.zikirEnabledKey]
        let backup = keys.map { ($0, d.object(forKey: $0)) }
        keys.forEach { d.removeObject(forKey: $0) }
        let firstApplied = NotificationManager.applyFirstGrantDefaults()
        let allOn = NotificationManager.prayerNames.allSatisfy { NotificationManager.isPrayerEnabled($0) }
        let zikirOff = !d.bool(forKey: NotificationManager.zikirEnabledKey)
        NotificationManager.setPrayerEnabled(false, for: "Yatsı")
        let secondApplied = NotificationManager.applyFirstGrantDefaults()
        let userChoiceKept = !NotificationManager.isPrayerEnabled("Yatsı")
        backup.forEach { d.set($0.1, forKey: $0.0) }
        check("T40", "İlk izinde 5 namaz alarmı açık, hatırlatıcılar kapalı; kullanıcının sonraki seçimi korunur",
              firstApplied && allOn && zikirOff && !secondApplied && userChoiceKept)

        // T41: Zil/Ayarlar ortak kaydı: değer yazılır ve ekranlar haberdar edilir.
        var notified = false
        let token = NotificationCenter.default.addObserver(forName: NotificationManager.prayerPrefsDidChange, object: nil, queue: nil) { _ in notified = true }
        let before = NotificationManager.isPrayerEnabled("Öğle")
        NotificationManager.setPrayerEnabled(!before, for: "Öğle")
        let changed = NotificationManager.isPrayerEnabled("Öğle") == !before
        NotificationManager.setPrayerEnabled(before, for: "Öğle")
        NotificationCenter.default.removeObserver(token)
        check("T41", "Zil düğmesi alarmı kaydeder ve diğer ekranlara haber verir", changed && notified)

        // T42: "Şimdi değil" denince 3 gün sormaz, sonra tekrar sorar.
        let now = Date()
        check("T42", "Bildirim açıklaması: hiç sorulmadıysa göster, 'Şimdi değil'den 1 gün sonra gösterme, 3 gün sonra göster",
              PermissionPrimer.shouldShow(now: now, lastDeclined: nil)
              && !PermissionPrimer.shouldShow(now: now, lastDeclined: now.addingTimeInterval(-86_400))
              && PermissionPrimer.shouldShow(now: now, lastDeclined: now.addingTimeInterval(-3 * 86_400)))

        let path = Bundle.main.path(forResource: "PrivacyInfo", ofType: "xcprivacy")
        check("T28", "Gizlilik bildirimi (PrivacyInfo) uygulamada", path != nil)

        let camera = Bundle.main.object(forInfoDictionaryKey: "NSCameraUsageDescription")
        let bgIDs = Bundle.main.object(forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers") as? [String]
        check("T29", "Kamera izni yok, arka plan görevi tanımlı",
              camera == nil && bgIDs?.contains(BackgroundRefresh.taskIdentifier) == true)
    }

    // MARK: - Ağ (internet gerekir)

    private static func networkTests() {
        // Kur'an: Diyanet meali gerçekten Türkçe ve 7 ayet (Fatiha).
        // Yâsîn (36): 83 ayet, Türkçe ve ardışık ayetlerde aynı meal tekrarı yok.
        var repeats = -1
        let quranOK = fetchJSON("https://api.alquran.cloud/v1/surah/36/tr.vakfi") { json in
            let data = json["data"] as? [String: Any]
            let ayahs = (data?["ayahs"] as? [[String: Any]])?.compactMap { $0["text"] as? String } ?? []
            let edition = data?["edition"] as? [String: Any]
            repeats = zip(ayahs, ayahs.dropFirst()).filter { $0 == $1 }.count
            return ayahs.count == 83 && (edition?["language"] as? String) == "tr"
        }
        check("T30", "Kur'an API: Diyanet Vakfı meali, Yâsîn 83 ayet, tekrar yok", quranOK && repeats == 0, "tekrar=\(repeats)")

        // T51: Hafız sesi sunucuda gerçekten var (Yâsîn 1. ayet = genel 3706).
        var audioOK = false
        if let url = RecitationPlayer.audioURL(globalAyahNumber: 3706) {
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            let done = DispatchSemaphore(value: 0)
            URLSession.shared.dataTask(with: request) { _, response, _ in
                let http = response as? HTTPURLResponse
                audioOK = http?.statusCode == 200 && (http?.value(forHTTPHeaderField: "Content-Type") ?? "").contains("audio")
                done.signal()
            }.resume()
            _ = done.wait(timeout: .now() + 20)
        }
        check("T51", "Hafız sesi sunucuda erişilebilir (Yâsîn 1. ayet, mp3)", audioOK)

        // T54: Türkçe okunuş kaynağı: Yâsîn 83 ayet, ilk ayet "yâ-sîn".
        var firstTranslit = "-"
        let translitOK = fetchJSON("https://api.alquran.cloud/v1/surah/36/tr.transliteration") { json in
            let ayahs = ((json["data"] as? [String: Any])?["ayahs"] as? [[String: Any]])?.compactMap { $0["text"] as? String } ?? []
            firstTranslit = ayahs.first ?? "-"
            return ayahs.count == 83
        }
        check("T54", "Türkçe okunuş kaynağı: Yâsîn 83 ayet, 1. ayet Türkçe yazım", translitOK && firstTranslit.hasPrefix("yâ"),
              firstTranslit)

        // Diyanet yöntemiyle (aladhan method=13) karşılaştırma: ±3 dk.
        // Kullanıcı başka yöntem seçmiş olsa da test Diyanet ile çalışır; sonra geri yüklenir.
        let methodBackupT02 = UserDefaults.standard.object(forKey: PrayerCalculation.methodKey)
        UserDefaults.standard.removeObject(forKey: PrayerCalculation.methodKey)
        let ankara = CLLocationCoordinate2D(latitude: 39.9334, longitude: 32.8597)
        let today = Date()
        guard let ours = PrayerCalculation.times(on: today, coordinate: ankara, timeZone: istanbulTZ) else {
            check("T02", "Ankara vakitleri Diyanet yöntemiyle ±3 dk", false, "hesap yok")
            return
        }
        var cal = Calendar(identifier: .gregorian); cal.timeZone = istanbulTZ
        let d = cal.dateComponents([.day, .month, .year], from: today)
        let url = String(format: "https://api.aladhan.com/v1/timings/%02d-%02d-%04d?latitude=39.9334&longitude=32.8597&method=13&timezonestring=Europe/Istanbul",
                         d.day!, d.month!, d.year!)
        var worst = 999.0
        _ = fetchJSON(url) { json in
            guard let timings = (json["data"] as? [String: Any])?["timings"] as? [String: String] else { return false }
            let pairs: [(String, Date)] = [("Fajr", ours.fajr), ("Dhuhr", ours.dhuhr), ("Asr", ours.asr), ("Maghrib", ours.maghrib), ("Isha", ours.isha)]
            worst = 0
            for (key, ourDate) in pairs {
                guard let hm = timings[key]?.prefix(5).split(separator: ":"), hm.count == 2,
                      let h = Int(hm[0]), let m = Int(hm[1]),
                      let ref = cal.date(bySettingHour: h, minute: m, second: 0, of: today) else { worst = 999; return false }
                worst = max(worst, abs(ourDate.timeIntervalSince(ref)) / 60)
            }
            return true
        }
        check("T02", "Ankara vakitleri Diyanet yöntemiyle ±3 dk", worst <= 3, String(format: "en büyük fark=%.1f dk", worst))
        if let m = methodBackupT02 { UserDefaults.standard.set(m, forKey: PrayerCalculation.methodKey) }
    }

    private static func fetchJSON(_ urlString: String, _ evaluate: ([String: Any]) -> Bool) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        let done = DispatchSemaphore(value: 0)
        var result: [String: Any]?
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data { result = try? JSONSerialization.jsonObject(with: data) as? [String: Any] }
            done.signal()
        }.resume()
        _ = done.wait(timeout: .now() + 20)
        guard let result else { return false }
        return evaluate(result)
    }
}
#endif
