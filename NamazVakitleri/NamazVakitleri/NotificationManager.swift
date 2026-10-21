import Foundation
import Combine
import UserNotifications
import CoreLocation
import Adhan
import AVFoundation

/// Namaz vakti, zikir, Kur'an okuma ve ayet hatırlatma bildirimlerini
/// kullanıcı tercihlerine göre planlar. Ayarlar ekranındaki anahtarlar
/// UserDefaults üzerinden okunur; konum veya tercih değiştiğinde
/// `rescheduleAll` çağrılarak uygulamanın kendi planladığı bildirimler
/// yenilenir: namaz vakitleri 7 gün, hatırlatmalar 3 gün ileri. Ertelenen
/// ("Birazdan Hatırlat") bildirimler korunur. Uygulama açılmasa da
/// BackgroundRefresh bu pencereyi düzenli olarak ileri taşır.
final class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate, AVAudioPlayerDelegate {
    static let shared = NotificationManager()

    /// Kullanıcının Ayarlar'dan seçtiği bildirim sesi. @Published olduğu
    /// için Ayarlar ekranı bunu izleyip değişikliği anında yansıtır -
    /// eskiden UserDefaults'tan doğrudan okuyup SwiftUI'a haber
    /// vermediğimiz için seçim ancak ekranı kapatıp açınca güncelleniyordu.
    @Published var selectedSoundChoice: String

    /// Şu anda önizleme olarak hangi ses dosyası çalıyorsa onun adı;
    /// çalmıyorsa nil. Ayarlar ekranındaki play/durdur ikonu bunu izler.
    @Published var currentlyPlayingFileName: String?

    private override init() {
        self.selectedSoundChoice = UserDefaults.standard.string(forKey: NotificationManager.soundChoiceKey)
            ?? NotificationManager.soundOptions[0].id
        super.init()
    }

    private let center = UNUserNotificationCenter.current()

    /// Uygulama ön plandayken bir namaz vakti bildirimi gelirse, sistem
    /// banner'ı yerine tam ekran alarm görünümü göstermek için bunlar
    /// dolduruluyor. RootView bunu izleyip fullScreenCover açıyor.
    @Published var activeAlarmTitle: String?
    @Published var activeAlarmBody: String?
    /// Açık alarm hangi vakte ait (alarm ekranındaki "Kıldım" bunu kaydeder).
    var activeAlarmPrayer: (name: String, dayKey: String)?

    /// Zikir ya da Kur'an okuma hatırlatıcısına basıldığında, MainTabView
    /// bunu izleyip ilgili sekmeye otomatik geçiyor.
    @Published var requestedTab: AppTab?

    // MARK: - UserDefaults anahtarları

    static let prayerNames = ["İmsak", "Öğle", "İkindi", "Akşam", "Yatsı"]

    static func prayerEnabledKey(_ name: String) -> String { "notif_prayer_enabled_\(name)" }

    /// Bir vaktin alarmı açıldı/kapandı (ana sayfa zili ve Ayarlar birbirini izler).
    static let prayerPrefsDidChange = Notification.Name("NotificationManager.prayerPrefsDidChange")

    static func isPrayerEnabled(_ name: String) -> Bool {
        UserDefaults.standard.bool(forKey: prayerEnabledKey(name))
    }

    static func setPrayerEnabled(_ enabled: Bool, for name: String) {
        UserDefaults.standard.set(enabled, forKey: prayerEnabledKey(name))
        NotificationCenter.default.post(name: prayerPrefsDidChange, object: name)
    }

    private static let defaultsAppliedKey = "notif_defaults_applied"

    /// İzin, kullanıcı tek bir vaktin zilini açarken verildiyse: diğer
    /// vakitleri kendiliğinden açma, sadece "varsayılanlar uygulandı" say.
    static func markFirstGrantDefaultsApplied() {
        UserDefaults.standard.set(true, forKey: defaultsAppliedKey)
    }

    /// Bildirim izni İLK kez verildiğinde (sadece bir kez) varsayılanlar:
    /// 5 vaktin namaz alarmı AÇIK. Zikir/Kur'an/ayet hatırlatmaları kapalı
    /// kalır (kullanıcı isterse Ayarlar'dan açar). Daha önce izin vermiş
    /// kullanıcıların ayarlarına dokunulmaz. Uygulandıysa true döner.
    @discardableResult
    static func applyFirstGrantDefaults() -> Bool {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: defaultsAppliedKey) else { return false }
        for name in prayerNames {
            defaults.set(true, forKey: prayerEnabledKey(name))
        }
        defaults.set(true, forKey: defaultsAppliedKey)
        NotificationCenter.default.post(name: prayerPrefsDidChange, object: nil)
        return true
    }
    static let prayerOffsetKey = "notif_prayer_offset" // 0 = vaktinde, 3 = 3 dk önce
    static let zikirEnabledKey = "notif_zikir_enabled"
    static let quranEnabledKey = "notif_quran_enabled"
    static let ayahEnabledKey = "notif_ayah_enabled"
    static let fridayEnabledKey = "notif_friday_enabled"
    /// Ramazan'da sahur alarmı (İmsak'tan önce). Varsayılan açık.
    static let sahurEnabledKey = "notif_sahur_enabled"
    static let sahurMinutesKey = "notif_sahur_minutes"   // 30 / 45 / 60
    /// Kandil ve bayram gibi dini günlerde hatırlatma. Varsayılan açık.
    static let religiousDaysEnabledKey = "notif_religious_enabled"

    private static func boolDefaultTrue(_ key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) == nil ? true : UserDefaults.standard.bool(forKey: key)
    }
    static var isSahurEnabled: Bool { boolDefaultTrue(sahurEnabledKey) }
    static var sahurMinutes: Int {
        let v = UserDefaults.standard.integer(forKey: sahurMinutesKey)
        return [30, 45, 60].contains(v) ? v : 45
    }
    static var isReligiousDaysEnabled: Bool { boolDefaultTrue(religiousDaysEnabledKey) }

    /// Bildirime iliştirilen bilgi: hangi vakit, hangi gün ("Kıldım" kaydı için).
    static let prayerInfoKey = "prayer"
    static let dayInfoKey = "day"

    /// Cuma hatırlatıcısı varsayılan olarak AÇIK; kullanıcı hiç dokunmadıysa
    /// (kayıtlı değer yoksa) açık sayılır.
    private var isFridayReminderEnabled: Bool {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: Self.fridayEnabledKey) == nil
            ? true
            : defaults.bool(forKey: Self.fridayEnabledKey)
    }

    private static let prayerCategoryID = "PRAYER_ALARM"
    private static let zikirCategoryID = "ZIKIR_REMINDER"
    private static let quranCategoryID = "QURAN_REMINDER"
    private static let ayahCategoryID = "AYAH_REMINDER"

    /// Kullanıcının Ayarlar'dan seçebileceği iki bildirim sesi. Dosyalar
    /// (alarm_1.caf, alarm_2.caf) Xcode projesine eklenmeden bu seçenekler
    /// sessizce sistemin varsayılan kısa sesine düşer, hata vermez.
    static let soundOptions: [(id: String, label: String, fileName: String)] = [
        ("1", "Bildirim Sesi", "alarm_1.caf"),
        ("2", "Ezan Sesi", "alarm_2.caf")
    ]
    static let soundChoiceKey = "notif_sound_choice"

    /// Ayarlar ekranındaki bir sese basıldığında çağrılır: hem seçimi
    /// kaydeder hem @Published sayesinde ekranın anında güncellenmesini
    /// sağlar.
    func selectSound(_ id: String) {
        selectedSoundChoice = id
        UserDefaults.standard.set(id, forKey: Self.soundChoiceKey)
    }

    private func selectedSound() -> UNNotificationSound {
        let fileName = Self.soundOptions.first(where: { $0.id == selectedSoundChoice })?.fileName
            ?? Self.soundOptions[0].fileName
        return UNNotificationSound(named: UNNotificationSoundName(fileName))
    }

    private var previewPlayer: AVAudioPlayer?

    /// Sadece Ayarlar'daki play ikonuna basıldığında çağrılır - satırın
    /// geri kalanına basmak artık sesi çalmıyor, sadece seçiyor.
    func playSoundPreview(fileName: String) {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: nil) else { return }
        do {
            previewPlayer = try AVAudioPlayer(contentsOf: url)
            previewPlayer?.delegate = self
            if DebugMute.isOn { previewPlayer?.volume = 0 }
            previewPlayer?.play()
            currentlyPlayingFileName = fileName
        } catch {
            // Dosya henüz projeye eklenmemiş olabilir, sessizce yut.
        }
    }

    func stopSoundPreview() {
        previewPlayer?.stop()
        previewPlayer = nil
        currentlyPlayingFileName = nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { self.currentlyPlayingFileName = nil }
    }
    private static let prayedActionID = "PRAYED_ACTION"
    private static let snoozeActionID = "SNOOZE_ACTION"

    /// Namaz vakti bildirimine, uygulamayı açmadan kilitli ekrandan bile
    /// basılabilecek "Kıldım" / "Birazdan Hatırlat" butonlarını tanımlar.
    /// Bunu bir kez, izin istenirken kaydediyoruz.
    private func registerNotificationCategories() {
        let prayedAction = UNNotificationAction(
            identifier: Self.prayedActionID,
            title: LocalizationManager.shared.t("alarm_prayed", fallback: "Kıldım"),
            options: []
        )
        let snoozeAction = UNNotificationAction(
            identifier: Self.snoozeActionID,
            title: LocalizationManager.shared.t("alarm_snooze", fallback: "Birazdan Hatırlat"),
            options: []
        )
        let prayerCategory = UNNotificationCategory(
            identifier: Self.prayerCategoryID,
            actions: [prayedAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
        // Zikir/Kur'an hatırlatıcılarının özel aksiyon butonu yok, sadece
        // bildirime dokunulduğunda ilgili sekmeye yönlendirmek için
        // kategori kimliğine ihtiyacımız var.
        let zikirCategory = UNNotificationCategory(
            identifier: Self.zikirCategoryID,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        let quranCategory = UNNotificationCategory(
            identifier: Self.quranCategoryID,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        let ayahCategory = UNNotificationCategory(
            identifier: Self.ayahCategoryID,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([prayerCategory, zikirCategory, quranCategory, ayahCategory])
    }

    /// iOS, bir uygulama için aynı anda en fazla 64 bekleyen bildirime
    /// izin verir. Bütçe: namaz 7 gün × 5 = 35, Cuma ≤ 2, hatırlatmalar
    /// 3 gün × 5 = 15, "uygulamayı aç" uyarısı 1 → en fazla 53. Kalan pay
    /// ertelenen bildirimler için.
    static let prayerWindowDays = 7
    private static let reminderWindowDays = 3

    /// Planlama işleri sırayla çalışsın diye tek bir seri kuyruk; aynı anda
    /// gelen istekler birbirinin bildirimlerini silmesin.
    private let scheduleQueue = DispatchQueue(label: "com.kocaksefa.NamazVakitleri.notification-schedule")
    /// Sadece ana thread'de değişir. Daha yeni bir istek gelince eskisi iptal olur.
    private var scheduleGeneration = 0
    private var pendingReschedule: DispatchWorkItem?
    /// Birleştirilen (iptal edilen) isteklerin tamamlanma bildirimleri de
    /// kaybolmasın; en son çalışan istekle birlikte çağrılır.
    private var pendingCompletions: [() -> Void] = []

    /// Uygulamanın her planlamada yeniden ürettiği bildirimler. Ertelenen
    /// ("prayer_snooze_") ve deneme ("prayer_test") bildirimleri dokunulmaz.
    static func isManagedIdentifier(_ id: String) -> Bool {
        if id.hasPrefix("prayer_snooze_") || id == "prayer_test" { return false }
        return ["prayer_", "friday_", "zikir_", "quran_", "ayah_", "keepalive_", "sahur_", "religious_"].contains { id.hasPrefix($0) }
    }

    // MARK: - İzin

    /// Uygulama açılır açılmaz çağrılır: izin henüz istenmemiş olsa bile
    /// bildirim delegesini ve aksiyon butonlarını hazırlar.
    func prepare() {
        center.delegate = self
        registerNotificationCategories()
    }

    /// Bildirim izninin güncel durumu (Ayarlar ekranındaki uyarı için).
    func authorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async { completion(settings.authorizationStatus) }
        }
    }

    /// Bildirim izni henüz hiç sorulmadıysa true döner.
    func isAuthorizationUndetermined(completion: @escaping (Bool) -> Void) {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus == .notDetermined)
            }
        }
    }

    /// Bildirim izni YENİ verildiğinde, son bilinen konumla bildirimleri
    /// hemen planlar (konum zaten çözülmüş olabileceği için HomeView'ın
    /// bir sonraki güncellemesini beklemeye gerek kalmaz).
    func rescheduleFromLastKnownLocation(completion: (() -> Void)? = nil) {
        guard let (coordinate, timeZone) = Self.lastKnownLocation() else {
            completion?()
            return
        }
        rescheduleAll(coordinate: coordinate, timeZone: timeZone, completion: completion)
    }

    /// HomeView'ın en son kaydettiği konum ve saat dilimi.
    static func lastKnownLocation() -> (CLLocationCoordinate2D, TimeZone)? {
        let defaults = UserDefaults.standard
        let lat = defaults.double(forKey: "lastKnownLatitude")
        let lon = defaults.double(forKey: "lastKnownLongitude")
        guard lat != 0 || lon != 0 else { return nil }
        let timeZone = TimeZone(identifier: defaults.string(forKey: "lastKnownTimeZoneID") ?? "") ?? .current
        return (CLLocationCoordinate2D(latitude: lat, longitude: lon), timeZone)
    }

    func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        center.delegate = self
        registerNotificationCategories()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async { completion?(granted) }
        }
    }

    // MARK: - Bildirim geldiğinde (uygulama açıkken)

    /// Namaz vakti bildirimi uygulama ön plandayken gelirse, sistem
    /// banner'ını bastırıp kendi tam ekran alarm görünümümüzü tetikleriz.
    /// Diğer (zikir/Kur'an/ayet) bildirimler normal banner+ses olarak
    /// gösterilmeye devam eder.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let content = notification.request.content
        if content.categoryIdentifier == Self.prayerCategoryID {
            let info = Self.prayerInfo(from: content)
            DispatchQueue.main.async {
                self.activeAlarmPrayer = info
                self.activeAlarmTitle = content.title
                self.activeAlarmBody = content.body
            }
            completionHandler([]) // Kendi tam ekranımızı gösteriyoruz, sistem banner'ı gerekmiyor.
        } else {
            completionHandler([.banner, .sound])
        }
    }

    func dismissActiveAlarm() {
        activeAlarmTitle = nil
        activeAlarmBody = nil
        activeAlarmPrayer = nil
    }

    /// Alarm ekranında "Kıldım"a basıldı.
    func markActiveAlarmPrayed() {
        if let info = activeAlarmPrayer {
            PrayerTracker.setPrayed(true, name: info.name, dayKey: info.dayKey)
        }
        dismissActiveAlarm()
    }

    static func prayerInfo(from content: UNNotificationContent) -> (name: String, dayKey: String)? {
        guard let name = content.userInfo[prayerInfoKey] as? String,
              let day = content.userInfo[dayInfoKey] as? String else { return nil }
        return (name, day)
    }

    /// Uygulama kapalıyken/arka plandayken gelen bir namaz vakti
    /// bildirimine kullanıcı DOKUNUP uygulamayı açtığında çağrılır.
    /// Telefon kilitliyken kendiliğinden tam ekran açılamıyor (bu iOS'un
    /// izin vermediği bir şey) ama kullanıcı bildirime dokunduğu anda
    /// onu doğrudan alarm ekranıyla karşılamak, ulaşabileceğimiz en
    /// yakın deneyim.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let content = response.notification.request.content

        if content.categoryIdentifier == Self.prayerCategoryID {
            switch response.actionIdentifier {
            case Self.prayedActionID:
                // Kilitli ekrandan "Kıldım": uygulamayı açmadan kaydet.
                if let info = Self.prayerInfo(from: content) {
                    DispatchQueue.main.async {
                        PrayerTracker.setPrayed(true, name: info.name, dayKey: info.dayKey)
                    }
                }
            case Self.snoozeActionID:
                // Kilitli ekrandan "Birazdan Hatırlat" butonuna basıldı,
                // uygulamayı açmadan 10 dakika sonrasına yeni bir
                // hatırlatma kur.
                scheduleSnooze(title: content.title, userInfo: content.userInfo)
            case UNNotificationDefaultActionIdentifier:
                // Butona değil, bildirimin gövdesine dokunuldu ->
                // uygulama açılıyor. Bildirim yeni geldiyse alarm ekranını
                // göster; saatler önceki eski bir bildirimse sadece ana
                // sayfayı aç (vakit çoktan geçmişken alarm çalmasın).
                let isFresh = Date().timeIntervalSince(response.notification.date) < 15 * 60
                let info = Self.prayerInfo(from: content)
                DispatchQueue.main.async {
                    if isFresh {
                        self.activeAlarmPrayer = info
                        self.activeAlarmTitle = content.title
                        self.activeAlarmBody = content.body
                    } else {
                        self.requestedTab = .home
                    }
                }
            default:
                break
            }
        } else if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            // Zikir/Kur'an hatırlatıcısının gövdesine dokunulduysa,
            // uygulama doğrudan ilgili sekmeyle açılsın.
            if content.categoryIdentifier == Self.zikirCategoryID {
                DispatchQueue.main.async { self.requestedTab = .zikirmatik }
            } else if content.categoryIdentifier == Self.quranCategoryID || content.categoryIdentifier == Self.ayahCategoryID {
                DispatchQueue.main.async { self.requestedTab = .quran }
            }
        }

        completionHandler()
    }

    /// Sistem saatini elle ileri almak, iOS'un zamanlı bildirimlerini
    /// güvenilir şekilde tetiklemiyor (Apple bunu böyle tasarlamış).
    /// Bu yüzden alarm görünümünü ve sesini test etmenin sağlam yolu,
    /// saatle hiç oynamadan 5 saniye sonra ateşlenecek gerçek bir
    /// bildirim planlamaktır.
    func scheduleTestPrayerAlarm() {
        let content = UNMutableNotificationContent()
        content.title = LocalizationManager.shared.t("notif_test_title", fallback: "Test: Namaz Vakti")
        content.body = LocalizationManager.shared.t("notif_test_body", fallback: "Bu bir deneme bildirimidir - gerçek namaz vakitlerinde de böyle görünecek.")
        content.sound = selectedSound()
        content.categoryIdentifier = Self.prayerCategoryID
        content.interruptionLevel = .timeSensitive
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "prayer_test", content: content, trigger: trigger)
        center.add(request)
    }

    /// Alarm ekranındaki "Birazdan Hatırlat" seçeneği için 10 dakika
    /// sonraya aynı kategoriyle yeni bir hatırlatma kurar.
    func scheduleSnooze(title: String, userInfo: [AnyHashable: Any] = [:]) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.userInfo = userInfo
        content.body = LocalizationManager.shared.t("notif_snooze_body", fallback: "Hatırlatma - namazını kılmayı unutma.")
        content.sound = selectedSound()
        content.categoryIdentifier = Self.prayerCategoryID
        content.interruptionLevel = .timeSensitive
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10 * 60, repeats: false)
        let request = UNNotificationRequest(identifier: "prayer_snooze_\(UUID().uuidString)", content: content, trigger: trigger)
        center.add(request)
    }

    func checkAuthorization(completion: @escaping (Bool) -> Void) {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus == .authorized)
            }
        }
    }

    // MARK: - Yeniden planlama

    /// Konum belli olduğunda (uygulama açılışı, konum/ayar değişikliği,
    /// arka plan yenilemesi) çağrılır. Ana thread'den çağrılmalı.
    /// Arka arkaya gelen istekler 0,4 sn içinde birleştirilir; sadece en
    /// sonuncusu uygulanır.
    func rescheduleAll(coordinate: CLLocationCoordinate2D, timeZone: TimeZone, completion: (() -> Void)? = nil) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.rescheduleAll(coordinate: coordinate, timeZone: timeZone, completion: completion) }
            return
        }
        pendingReschedule?.cancel()
        if let completion { pendingCompletions.append(completion) }
        scheduleGeneration += 1
        let generation = scheduleGeneration
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let completions = self.pendingCompletions
            self.pendingCompletions = []
            self.performReschedule(coordinate: coordinate, timeZone: timeZone, generation: generation) {
                completions.forEach { $0() }
            }
        }
        pendingReschedule = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    private func performReschedule(coordinate: CLLocationCoordinate2D, timeZone: TimeZone, generation: Int, completion: (() -> Void)?) {
        center.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                guard let self,
                      settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional,
                      generation == self.scheduleGeneration else {
                    completion?()
                    return
                }
                // Metinler (dil) ve ses seçimi ana thread'de okunur; kayıt
                // işi seri kuyrukta yapılır.
                self.registerNotificationCategories()
                let requests = self.buildRequests(coordinate: coordinate, timeZone: timeZone)
                self.scheduleQueue.async {
                    self.replaceManagedRequests(with: requests)
                    DispatchQueue.main.async { completion?() }
                }
            }
        }
    }

    /// Sadece uygulamanın yönettiği bildirimleri değiştirir; ertelenenler kalır.
    private func replaceManagedRequests(with requests: [UNNotificationRequest]) {
        let newIDs = Set(requests.map(\.identifier))
        let fetched = DispatchSemaphore(value: 0)
        var staleIDs: [String] = []
        center.getPendingNotificationRequests { pending in
            staleIDs = pending.map(\.identifier).filter { Self.isManagedIdentifier($0) && !newIDs.contains($0) }
            fetched.signal()
        }
        // Sistem cevap vermezse kuyruk sonsuza kadar kilitlenmesin. Liste
        // alınamadıysa hiçbir şey silme (eski veriye göre silmek riskli).
        if fetched.wait(timeout: .now() + 10) == .success {
            center.removePendingNotificationRequests(withIdentifiers: staleIDs)
        }

        let added = DispatchGroup()
        for request in requests {
            added.enter()
            center.add(request) { _ in added.leave() }
        }
        _ = added.wait(timeout: .now() + 15)
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    /// Ana thread'de çağrılır: planlanacak bütün bildirimleri üretir.
    func buildRequests(coordinate: CLLocationCoordinate2D, timeZone: TimeZone) -> [UNNotificationRequest] {
        var requests = prayerRequests(coordinate: coordinate, timeZone: timeZone)
        requests += sahurRequests(coordinate: coordinate, timeZone: timeZone)
        requests += religiousDayRequests(timeZone: timeZone)
        requests += randomDailyRequests(defaultsKey: Self.zikirEnabledKey, identifierPrefix: "zikir", messages: Self.zikirMessages, count: 1, categoryID: Self.zikirCategoryID)
        requests += randomDailyRequests(defaultsKey: Self.quranEnabledKey, identifierPrefix: "quran", messages: Self.quranMessages, count: 1, categoryID: Self.quranCategoryID)
        requests += randomDailyRequests(defaultsKey: Self.ayahEnabledKey, identifierPrefix: "ayah", messages: Self.sampleAyahs, count: 3, categoryID: Self.ayahCategoryID)
        return Self.trimmedToBudget(requests)
    }

    /// iOS en fazla 64 bekleyen bildirim tutar. Ertelemeler için pay
    /// bırakarak 56'yı aşarsak önce rastgele hatırlatmaları, sonra dini
    /// gün/Cuma bildirimlerini, en geç tarihlilerden başlayarak çıkarırız.
    /// Namaz, sahur ve "alarmlar duracak" bildirimleri hiç çıkarılmaz.
    static let notificationBudget = 56

    static func trimmedToBudget(_ requests: [UNNotificationRequest]) -> [UNNotificationRequest] {
        guard requests.count > notificationBudget else { return requests }
        func priority(_ id: String) -> Int {
            if id.hasPrefix("prayer_") || id.hasPrefix("sahur_") || id.hasPrefix("keepalive_") { return 0 }
            if id.hasPrefix("friday_") || id.hasPrefix("religious_") { return 1 }
            return 2
        }
        func fireDate(_ r: UNNotificationRequest) -> Date {
            (r.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ?? .distantFuture
        }
        let ranked = requests.enumerated().sorted { a, b in
            let pa = priority(a.element.identifier), pb = priority(b.element.identifier)
            return pa != pb ? pa < pb : fireDate(a.element) < fireDate(b.element)
        }
        let kept = Set(ranked.prefix(notificationBudget).map(\.offset))
        return requests.enumerated().filter { kept.contains($0.offset) }.map(\.element)
    }

    // MARK: - Sahur (Ramazan)

    func sahurRequests(coordinate: CLLocationCoordinate2D, timeZone: TimeZone, now: Date = Date()) -> [UNNotificationRequest] {
        guard Self.isSahurEnabled else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let today = calendar.startOfDay(for: now)
        let minutes = Self.sahurMinutes
        let L = LocalizationManager.shared
        var requests: [UNNotificationRequest] = []
        for dayOffset in 0..<Self.prayerWindowDays {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today),
                  let times = PrayerCalculation.times(on: day, coordinate: coordinate, timeZone: timeZone),
                  RamadanInfo.dayOfRamadan(times.fajr, timeZone: timeZone) != nil else { continue }
            let fireDate = times.fajr.addingTimeInterval(-Double(minutes) * 60)
            guard fireDate > now else { continue }
            let content = UNMutableNotificationContent()
            content.title = L.t("sahur_title", fallback: "Sahur vakti")
            content.body = L.tf("sahur_body", "İmsak'a %d dakika kaldı. Hayırlı sahurlar!", minutes)
            content.sound = selectedSound()
            content.interruptionLevel = .timeSensitive
            requests.append(UNNotificationRequest(identifier: "sahur_\(dayOffset)", content: content,
                                                  trigger: Self.trigger(for: fireDate, calendar: calendar)))
        }
        return requests
    }

    // MARK: - Dini günler (kandil, bayram…)

    private func religiousDayRequests(timeZone: TimeZone) -> [UNNotificationRequest] {
        guard Self.isReligiousDaysEnabled else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let L = LocalizationManager.shared
        let horizon = Date().addingTimeInterval(60 * 24 * 3600)
        let upcoming = ReligiousDays.upcoming().filter { $0.date <= horizon }.prefix(3)
        var requests: [UNNotificationRequest] = []
        for (index, day) in upcoming.enumerated() {
            var fireComps = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: day.date)
            fireComps.hour = 10
            fireComps.minute = 0
            guard let fireDate = calendar.date(from: fireComps), fireDate > Date() else { continue }
            let name = L.x(day.name)
            let isNight = day.name.contains("Kandil") || day.name.contains("Gecesi")
            let content = UNMutableNotificationContent()
            content.title = isNight
                ? L.tf("religious_night_title", "Bu gece %@", name)
                : L.tf("religious_day_title", "Bugün %@", name)
            content.body = isNight
                ? L.t("religious_night_body", fallback: "Hayırlı kandiller! Bu geceyi ibadet ve dua ile değerlendirmeyi unutma.")
                : L.t("religious_day_body", fallback: "Hayırlı ve bereketli günler dileriz.")
            content.sound = .default
            requests.append(UNNotificationRequest(identifier: "religious_\(index)", content: content,
                                                  trigger: Self.trigger(for: fireDate, calendar: calendar)))
        }
        return requests
    }

    /// Takvim tetikleyicisi, saat dilimi verilmezse bileşenleri CİHAZIN
    /// saat diliminde yorumlar. Seçilen konumun saat dilimini açıkça
    /// yazıyoruz ki telefon başka bir saat dilimindeyken alarm kaymasın.
    private static func trigger(for date: Date, calendar: Calendar) -> UNCalendarNotificationTrigger {
        var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        comps.timeZone = calendar.timeZone
        return UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
    }

    // MARK: - Namaz vakti bildirimleri

    private func prayerRequests(coordinate: CLLocationCoordinate2D, timeZone: TimeZone) -> [UNNotificationRequest] {
        let defaults = UserDefaults.standard
        let offsetMinutes = defaults.integer(forKey: Self.prayerOffsetKey)
        let L = LocalizationManager.shared
        let sound = selectedSound()
        let now = Date()

        let prayerMap: [(Prayer, String)] = [
            (.fajr, "İmsak"), (.dhuhr, "Öğle"), (.asr, "İkindi"), (.maghrib, "Akşam"), (.isha, "Yatsı")
        ]

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let today = calendar.startOfDay(for: now)

        var requests: [UNNotificationRequest] = []

        for dayOffset in 0..<Self.prayerWindowDays {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today),
                  let times = PrayerCalculation.times(on: day, coordinate: coordinate, timeZone: timeZone) else { continue }

            if let friday = fridayRequest(day: day, dayOffset: dayOffset, dhuhr: times.dhuhr, calendar: calendar) {
                requests.append(friday)
            }

            for (prayer, name) in prayerMap {
                guard defaults.bool(forKey: Self.prayerEnabledKey(name)) else { continue }
                let fireDate = times.time(for: prayer).addingTimeInterval(-Double(offsetMinutes) * 60)
                guard fireDate > now else { continue }

                let content = UNMutableNotificationContent()
                if offsetMinutes > 0 {
                    content.title = L.tf("notif_before_title", "%@ vaktine %d dakika kaldı", L.x(name), offsetMinutes)
                    content.body = L.t("notif_before_body", fallback: "Hazırlanmaya başlayabilirsin.")
                } else {
                    content.title = L.tf("notif_now_title", "%@ Vakti Girdi", L.x(name))
                    content.body = L.tf("notif_now_body", "%@ namazını kılmayı unutma.", L.x(name))
                }
                // Kullanıcının Ayarlar'dan seçtiği iki tondan biri (bkz.
                // Self.soundOptions).
                content.sound = sound
                content.categoryIdentifier = Self.prayerCategoryID
                content.userInfo = [Self.prayerInfoKey: name, Self.dayInfoKey: PrayerTracker.dayKey(day, timeZone: timeZone)]
                // Odak/Rahatsız Etme modlarını delip geçer (entitlement gerekli:
                // com.apple.developer.usernotifications.time-sensitive).
                content.interruptionLevel = .timeSensitive
                content.relevanceScore = 1.0

                requests.append(UNNotificationRequest(
                    identifier: "prayer_\(name)_\(dayOffset)",
                    content: content,
                    trigger: Self.trigger(for: fireDate, calendar: calendar)
                ))
            }
        }

        // Güvenlik ağı: uygulama ve arka plan yenilemesi uzun süre hiç
        // çalışmazsa, planlı alarmlar bitmeden bir gün önce kullanıcıyı uyar.
        // Uygulama her açıldığında bu uyarı ileri kayar, yani normalde hiç gelmez.
        // Sadece gerçekten alarm kurulduysa (vakit hesaplanabildiyse) uyar.
        if requests.contains(where: { $0.identifier.hasPrefix("prayer_") }),
           let lastDay = calendar.date(byAdding: .day, value: Self.prayerWindowDays - 2, to: today),
           let fireDate = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: lastDay),
           fireDate > now {
            let content = UNMutableNotificationContent()
            content.title = L.t("notif_keepalive_title", fallback: "Namaz alarmları yakında duracak")
            content.body = L.t("notif_keepalive_body", fallback: "Alarmların devam etmesi için uygulamayı bir kez aç.")
            content.sound = .default
            requests.append(UNNotificationRequest(
                identifier: "keepalive_0",
                content: content,
                trigger: Self.trigger(for: fireDate, calendar: calendar)
            ))
        }

        return requests
    }

    // MARK: - Cuma hatırlatmaları

    /// Perşembe akşamı "yarın Cuma" ve Cuma günü, Cuma namazına (öğle
    /// vakti) 1 saat kala "bugün Cuma namazı var" bildirimi.
    /// Alarm değil, normal bildirim olarak gider.
    private func fridayRequest(day: Date, dayOffset: Int, dhuhr: Date, calendar: Calendar) -> UNNotificationRequest? {
        guard isFridayReminderEnabled else { return nil }
        let weekday = calendar.component(.weekday, from: day) // 1 = Pazar ... 5 = Perşembe, 6 = Cuma
        let L = LocalizationManager.shared

        let content = UNMutableNotificationContent()
        content.sound = .default
        let fireDate: Date?

        if weekday == 5 {
            // Perşembe, yerel saatle 20:00
            fireDate = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: day)
            content.title = L.t("friday_eve_title", fallback: "Yarın Cuma")
            content.body = L.t("friday_eve_body", fallback: "Hayırlı Cumalar! Yarın Cuma günü, Cuma namazı için hazırlanmayı unutma.")
        } else if weekday == 6 {
            fireDate = dhuhr.addingTimeInterval(-3600)
            content.title = L.t("friday_title", fallback: "Bugün Cuma namazı var")
            content.body = L.t("friday_body", fallback: "Cuma namazına 1 saat kaldı. Hayırlı Cumalar!")
        } else {
            return nil
        }

        guard let fireDate, fireDate > Date() else { return nil }
        return UNNotificationRequest(
            identifier: "friday_\(weekday)_\(dayOffset)",
            content: content,
            trigger: Self.trigger(for: fireDate, calendar: calendar)
        )
    }

    // MARK: - Rastgele saatli hatırlatmalar (zikir / Kur'an / ayet)

    private func randomDailyRequests(defaultsKey: String, identifierPrefix: String, messages: [(String, String)], count: Int = 1, categoryID: String? = nil) -> [UNNotificationRequest] {
        guard UserDefaults.standard.bool(forKey: defaultsKey) else { return [] }
        let calendar = Calendar.current
        var requests: [UNNotificationRequest] = []

        for dayOffset in 0..<Self.reminderWindowDays {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: Date()) else { continue }

            for i in 0..<count {
                // Gün içinde 09:00-21:00 arası "rastgele" bir saat. Aynı gün
                // ve aynı hatırlatma için her planlamada AYNI saat çıkar
                // (tarihten türetilen sabit tohum). Böylece arka plan
                // yenilemesi bekleyen bir hatırlatmayı silmez ya da kaydırmaz.
                var comps = calendar.dateComponents([.year, .month, .day], from: day)
                var rng = SeededGenerator(seed: Self.reminderSeed(comps, prefix: identifierPrefix, index: i))
                comps.hour = Int.random(in: 9...21, using: &rng)
                comps.minute = Int.random(in: 0...59, using: &rng)
                guard let fireDate = calendar.date(from: comps), fireDate > Date() else { continue }

                let (title, body) = messages.isEmpty
                    ? (LocalizationManager.shared.t("notif_reminder", fallback: "Hatırlatma"), "")
                    : messages[Int.random(in: 0..<messages.count, using: &rng)]
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = .default
                if let categoryID {
                    content.categoryIdentifier = categoryID
                }

                requests.append(UNNotificationRequest(
                    identifier: "\(identifierPrefix)_\(dayOffset)_\(i)",
                    content: content,
                    trigger: Self.trigger(for: fireDate, calendar: calendar)
                ))
            }
        }
        return requests
    }

    /// Gün + hatırlatma türü + sıra numarasından sabit bir tohum
    /// (Swift'in hashValue'su her açılışta değiştiği için kullanılmaz).
    static func reminderSeed(_ comps: DateComponents, prefix: String, index: Int) -> UInt64 {
        var seed = UInt64((comps.year ?? 0) * 10_000 + (comps.month ?? 0) * 100 + (comps.day ?? 0))
        for byte in prefix.utf8 { seed = seed &* 31 &+ UInt64(byte) }
        return seed &* 1_000_003 &+ UInt64(index)
    }

    /// Basit, tekrarlanabilir rastgele sayı üreteci (SplitMix64).
    struct SeededGenerator: RandomNumberGenerator {
        private var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }

    // MARK: - Mesaj havuzları

    // Mesaj havuzları, bildirimler planlanırken SEÇİLİ DİLE göre üretilir.
    // Türkçe metinler fallback olarak burada duruyor, İngilizceleri
    // Localization.swift içinde.
    private static func localizedMessages(prefix: String, _ turkish: [(String, String)]) -> [(String, String)] {
        let L = LocalizationManager.shared
        return turkish.enumerated().map { index, message in
            (L.t("\(prefix)_msg_\(index + 1)_t", fallback: message.0),
             L.t("\(prefix)_msg_\(index + 1)_b", fallback: message.1))
        }
    }

    private static var zikirMessages: [(String, String)] {
        localizedMessages(prefix: "zikir", [
            ("Zikir Vakti", "Bir dakikanı ayır: Sübhanallah, Elhamdülillah, Allahu Ekber."),
            ("Kalbini Rahatlat", "Şimdi biraz zikirle meşgul olmaya ne dersin?"),
            ("Hatırlatma", "Bugün istiğfar etmeyi unutma."),
            ("Zikirmatik Seni Bekliyor", "Birkaç dakikanı zikre ayırmak ister misin?")
        ])
    }

    private static var quranMessages: [(String, String)] {
        localizedMessages(prefix: "quran", [
            ("Kur'an Okuma Vakti", "Bugün birkaç ayet okumaya ne dersin?"),
            ("Hatırlatma", "Az da olsa düzenli Kur'an okumak güzeldir."),
            ("Kur'an-ı Kerim", "Bugün Kur'an'dan bir sayfa okuma fırsatın oldu mu?")
        ])
    }

    // Ayet metinleri AyahPool.swift'teki ortak havuzdan, seçili dile göre.
    private static var sampleAyahs: [(String, String)] {
        AyahPool.localized().map { ($0.reference, $0.text) }
    }
}
