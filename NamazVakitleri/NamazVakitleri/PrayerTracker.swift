import Foundation

/// "Kıldım" kaydı ve kaza namazı sayacı. Veriler sadece cihazda
/// (UserDefaults) tutulur.
enum PrayerTracker {
    /// Bir namaz işaretlendi/işareti kaldırıldı ya da kaza sayısı değişti.
    static let didChange = Notification.Name("PrayerTracker.didChange")

    private static let logKey = "prayer_log"          // [gün: [vakit adı]]
    private static func kazaKey(_ name: String) -> String { "kaza_count_\(name)" }

    /// Gün anahtarı ("2026-10-21"), konumun saat diliminde.
    static func dayKey(_ date: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private static var log: [String: [String]] {
        get { UserDefaults.standard.dictionary(forKey: logKey) as? [String: [String]] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: logKey) }
    }

    static func isPrayed(_ name: String, dayKey: String) -> Bool {
        log[dayKey]?.contains(name) ?? false
    }

    static func setPrayed(_ prayed: Bool, name: String, dayKey: String) {
        var all = log
        var names = Set(all[dayKey] ?? [])
        if prayed { names.insert(name) } else { names.remove(name) }
        all[dayKey] = names.isEmpty ? nil : Array(names).sorted()
        // Kayıt büyümesin: 400 günden eski kayıtları sil.
        let keys = all.keys.sorted()
        if keys.count > 400 {
            for old in keys.prefix(keys.count - 400) { all[old] = nil }
        }
        log = all
        NotificationCenter.default.post(name: didChange, object: nil)
    }

    static func prayedCount(dayKey: String) -> Int {
        log[dayKey]?.filter { NotificationManager.prayerNames.contains($0) }.count ?? 0
    }

    // MARK: - Özel gün (namazdan muaf günler)

    private static let excusedKey = "excused_days"   // ["2026-10-21", …]

    static func isExcused(dayKey: String) -> Bool {
        (UserDefaults.standard.stringArray(forKey: excusedKey) ?? []).contains(dayKey)
    }

    /// Özel gün açılınca o gün seriyi bozmaz ve sayılmaz (kadınlar için).
    static func setExcused(_ excused: Bool, dayKey: String) {
        var days = Set(UserDefaults.standard.stringArray(forKey: excusedKey) ?? [])
        if excused { days.insert(dayKey) } else { days.remove(dayKey) }
        UserDefaults.standard.set(Array(Array(days).sorted().suffix(400)), forKey: excusedKey)
        NotificationCenter.default.post(name: didChange, object: nil)
    }

    /// Bugünden geriye, 5 vaktin hepsinin kılındığı ardışık gün sayısı.
    /// Bugün henüz tamamlanmadıysa dünden saymaya başlar. Özel günler
    /// atlanır: seriyi bozmaz, seriye eklenmez.
    static func streak(today: Date = Date(), timeZone: TimeZone = .current) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var day = today
        let todayKey = dayKey(day, timeZone: timeZone)
        if prayedCount(dayKey: todayKey) < 5 || isExcused(dayKey: todayKey) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var count = 0
        for _ in 0..<400 {
            let key = dayKey(day, timeZone: timeZone)
            if isExcused(dayKey: key) {
                // atla: özel gün seriyi bozmaz
            } else if prayedCount(dayKey: key) >= 5 {
                count += 1
            } else {
                break
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    // MARK: - Kaza namazı

    static func kazaCount(_ name: String) -> Int {
        UserDefaults.standard.integer(forKey: kazaKey(name))
    }

    static func setKazaCount(_ count: Int, for name: String) {
        UserDefaults.standard.set(max(0, count), forKey: kazaKey(name))
        NotificationCenter.default.post(name: didChange, object: nil)
    }

    /// Kaza listesi: 5 vakit + Vitir (vacip; kazası gerekir).
    static let kazaNames = NotificationManager.prayerNames + ["Vitir"]

    static var totalKaza: Int {
        kazaNames.reduce(0) { $0 + kazaCount($1) }
    }

    /// Kaza orucu (Ramazan'da tutulamayan günler), namazlardan ayrı sayılır.
    static let fastingKazaName = "Oruç"

    /// Namaz adı: "İmsak" bir vakittir, namazın adı "Sabah"tır (imamın düzeltmesi).
    static func namazName(_ name: String) -> String {
        let loc = LocalizationManager.shared
        switch name {
        case "İmsak": return loc.t("prayer_sabah", fallback: "Sabah")
        case "Vitir": return loc.t("prayer_vitir", fallback: "Vitir")
        default: return loc.x(name)
        }
    }
}
