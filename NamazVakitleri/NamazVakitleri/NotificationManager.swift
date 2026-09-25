import Foundation
import UserNotifications
import Adhan

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// Günün namaz vakitleri için bildirim planlar. Güneş (sunrise) namaz
    /// vakti olmadığı için bildirime dahil edilmez. Sadece gelecekteki
    /// vakitler için bildirim kurulur, geçmiş olanlar atlanır.
    func scheduleNotifications(for prayerTimes: PrayerTimes, timeZone: TimeZone) {
        guard UserDefaults.standard.bool(forKey: "ezanNotificationsEnabled") else { return }

        let center = UNUserNotificationCenter.current()
        let ids = ["prayer_fajr", "prayer_dhuhr", "prayer_asr", "prayer_maghrib", "prayer_isha"]
        center.removePendingNotificationRequests(withIdentifiers: ids)

        let entries: [(id: String, name: String, date: Date)] = [
            ("prayer_fajr", "İmsak", prayerTimes.fajr),
            ("prayer_dhuhr", "Öğle", prayerTimes.dhuhr),
            ("prayer_asr", "İkindi", prayerTimes.asr),
            ("prayer_maghrib", "Akşam", prayerTimes.maghrib),
            ("prayer_isha", "Yatsı", prayerTimes.isha)
        ]

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        for entry in entries {
            guard entry.date > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = "\(entry.name) Vakti"
            content.body = "\(entry.name) namazı vakti girdi."
            content.sound = .default

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: entry.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: entry.id, content: content, trigger: trigger)
            center.add(request)
        }
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
