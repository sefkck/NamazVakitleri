import ActivityKit
import AlarmKit
import CoreLocation
import Foundation
import SwiftUI

/// "Gerçek alarm" ayarı: namaz vakitlerini iOS'un saat uygulaması gibi
/// AlarmKit ile kurar. Sessiz modda ve Odak'ta da sesli çalar, kilit
/// ekranında tam ekran görünür. Açıkken bu günlerin namaz bildirimleri
/// sessiz gelir (iki kez ses olmasın); "Kıldım" düğmesi bildirimde kalır.
enum PrayerAlarms {
    static let enabledKey = "notif_alarmkit_enabled"
    /// Önümüzdeki kaç gün alarm kurulur. Uygulama açıldıkça ve arka plan
    /// yenilemesinde ileri kayar; sonraki günler normal sesli bildirimle gelir.
    static let alarmDays = 3
    static let snoozeSeconds: TimeInterval = 10 * 60

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    /// Sessiz modda çalmak sabah uyanmak için istenir; gündüz (toplantı, ders,
    /// cami) zararlıdır. Bu yüzden vakit vakit seçilir; varsayılan sadece İmsak.
    static func choiceKey(_ name: String) -> String { "notif_alarmkit_prayer_\(name)" }
    static let skipFridayKey = "notif_alarmkit_skip_friday"

    static func isChosen(_ name: String) -> Bool {
        (UserDefaults.standard.object(forKey: choiceKey(name)) as? Bool) ?? (name == "İmsak")
    }

    static func setChosen(_ on: Bool, _ name: String) {
        UserDefaults.standard.set(on, forKey: choiceKey(name))
    }

    /// Cuma öğlesi (Cuma namazı, hutbe) alarm çalmasın; varsayılan açık.
    static var skipFriday: Bool {
        (UserDefaults.standard.object(forKey: skipFridayKey) as? Bool) ?? true
    }

    /// Bu vakit bu gün alarmla mı çalar? (Bildirim de buna göre sessiz gelir.)
    static func applies(_ name: String, on day: Date, calendar: Calendar,
                        chosen: (String) -> Bool = isChosen, skipFriday: Bool = skipFriday) -> Bool {
        guard chosen(name) else { return false }
        if skipFriday, name == "Öğle", calendar.component(.weekday, from: day) == 6 { return false }
        return true
    }

    static var isAuthorized: Bool { AlarmManager.shared.authorizationState == .authorized }

    /// Ayar açık ve izin verilmiş: alarmlar kurulur, bildirimler sessiz gelir.
    static var isActive: Bool { isEnabled && isAuthorized }

    /// İzin ister; verilmezse ayar kapalı kalır.
    static func enable(completion: @escaping (Bool) -> Void) {
        Task { @MainActor in
            let state = (try? await AlarmManager.shared.requestAuthorization()) ?? .denied
            let granted = state == .authorized
            UserDefaults.standard.set(granted, forKey: enabledKey)
            completion(granted)
        }
    }

    static func disable() {
        UserDefaults.standard.set(false, forKey: enabledKey)
        cancelScheduled()
    }

    /// Kurulacak alarmlar: açık vakitler, bildirim zamanı tercihi (vaktinde / 3 dk önce), geçmiş olanlar hariç.
    static func planned(now: Date, coordinate: CLLocationCoordinate2D, timeZone: TimeZone,
                        enabledPrayers: Set<String>, offsetMinutes: Int, days: Int = alarmDays,
                        chosen: (String) -> Bool = isChosen, skipFriday: Bool = skipFriday) -> [(name: String, date: Date)] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let today = calendar.startOfDay(for: now)
        var result: [(name: String, date: Date)] = []
        for dayOffset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today),
                  let times = PrayerCalculation.times(on: day, coordinate: coordinate, timeZone: timeZone) else { continue }
            let map: [(String, Date)] = [("İmsak", times.fajr), ("Öğle", times.dhuhr), ("İkindi", times.asr),
                                         ("Akşam", times.maghrib), ("Yatsı", times.isha)]
            for (name, time) in map where enabledPrayers.contains(name)
                && applies(name, on: day, calendar: calendar, chosen: chosen, skipFriday: skipFriday) {
                let date = time.addingTimeInterval(-Double(offsetMinutes) * 60)
                if date > now { result.append((name, date)) }
            }
        }
        return result
    }

    /// Önceki kurulum bitmeden yenisi başlamasın (yoksa aynı vakte iki alarm kurulabiliyordu).
    private static var syncTask: Task<Void, Never>?

    /// Bekleyen alarmları silip yeniden kurar. Çalan ya da ertelenmiş alarma dokunmaz.
    /// `completion` bütün alarmlar kurulunca çağrılır (arka plan görevi erken bitmesin).
    static func sync(coordinate: CLLocationCoordinate2D, timeZone: TimeZone, completion: (() -> Void)? = nil) {
        guard isActive else {
            let previous = syncTask
            syncTask = Task {
                await previous?.value
                cancelScheduled()
                completion?()
            }
            return
        }
        let enabled = Set(NotificationManager.prayerNames.filter(NotificationManager.isPrayerEnabled))
        let offset = UserDefaults.standard.integer(forKey: NotificationManager.prayerOffsetKey)
        let items = planned(now: Date(), coordinate: coordinate, timeZone: timeZone, enabledPrayers: enabled, offsetMinutes: offset)
        let L = LocalizationManager.shared
        let titles = items.map { offset > 0
            ? L.tf("notif_before_title", "%@ vaktine %d dakika kaldı", L.x($0.name), offset)
            : L.tf("notif_now_title", "%@ Vakti Girdi", L.x($0.name)) }
        let snoozeText = L.t("alarm_snooze_real", fallback: "Ertele")
        let sound = NotificationManager.shared.selectedSoundFileName
        let previous = syncTask
        syncTask = Task {
            await previous?.value
            cancelScheduled()
            for (item, title) in zip(items, titles) {
                await schedule(title: title, prayerName: item.name, date: item.date, snoozeText: snoozeText, sound: sound)
            }
            completion?()
        }
    }

    /// Ayarlar'daki deneme düğmesi: 5 sn sonra gerçek alarm.
    static func scheduleTest() {
        let L = LocalizationManager.shared
        let title = L.t("notif_test_title", fallback: "Örnek: Namaz Vakti")
        let snooze = L.t("alarm_snooze_real", fallback: "Ertele")
        let sound = NotificationManager.shared.selectedSoundFileName
        Task { await schedule(title: title, prayerName: "", date: Date().addingTimeInterval(5), snoozeText: snooze, sound: sound) }
    }

    private static func schedule(title: String, prayerName: String, date: Date, snoozeText: String, sound: String) async {
        let snooze = AlarmButton(text: LocalizedStringResource(stringLiteral: snoozeText), textColor: .white, systemImageName: "zzz")
        let alert = AlarmPresentation.Alert(title: LocalizedStringResource(stringLiteral: title),
                                            secondaryButton: snooze, secondaryButtonBehavior: .countdown)
        let countdown = AlarmPresentation.Countdown(title: LocalizedStringResource(stringLiteral: title))
        let attributes = AlarmAttributes(presentation: AlarmPresentation(alert: alert, countdown: countdown),
                                         metadata: PrayerAlarmMetadata(prayerName: prayerName),
                                         tintColor: AppTheme.accent)
        let config = AlarmManager.AlarmConfiguration(
            countdownDuration: Alarm.CountdownDuration(preAlert: nil, postAlert: snoozeSeconds),
            schedule: .fixed(date),
            attributes: attributes,
            sound: .named(sound))
        _ = try? await AlarmManager.shared.schedule(id: UUID(), configuration: config)
    }

    static func cancelScheduled() {
        let alarms = (try? AlarmManager.shared.alarms) ?? []
        for alarm in alarms where alarm.state == .scheduled {
            try? AlarmManager.shared.cancel(id: alarm.id)
        }
    }
}
