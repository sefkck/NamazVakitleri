import Foundation

/// Bildirim izninden ÖNCE gösterilen kısa açıklama ("Ezan vakitlerinde
/// haber verelim mi?"). Sistem penceresi böylece kullanıcının kendi
/// dokunuşuyla açılır; eskiden 30 sn sonra aniden çıkıp kullanıcının o
/// anki dokunuşunu yutuyordu.
enum PermissionPrimer {
    private static let declinedAtKey = "notif_primer_declined_at"
    /// "Şimdi değil" denirse bu kadar gün sonra tekrar sorulur.
    static let repromptDays: Double = 3

    static func shouldShow(now: Date = Date(), lastDeclined: Date? = UserDefaults.standard.object(forKey: declinedAtKey) as? Date) -> Bool {
        guard let lastDeclined else { return true }
        return now.timeIntervalSince(lastDeclined) >= repromptDays * 24 * 3600
    }

    static func markDeclined(now: Date = Date()) {
        UserDefaults.standard.set(now, forKey: declinedAtKey)
    }
}
