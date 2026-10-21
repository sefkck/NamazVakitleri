import AppIntents
import CoreLocation
import Foundation

/// Siri ve Kestirmeler: "Safa sıradaki namaz", "Safa kerahat vakti mi?".
/// Uygulamayı açmadan cevap verir. Konum olarak uygulamanın en son
/// kaydettiği konum kullanılır (ana sayfa her açılışta kaydeder).
enum SiriPrayerInfo {
    static func savedLocation() -> (CLLocationCoordinate2D, TimeZone)? {
        let d = UserDefaults.standard
        let lat = d.double(forKey: "lastKnownLatitude")
        let lon = d.double(forKey: "lastKnownLongitude")
        guard lat != 0 || lon != 0 else { return nil }
        let tz = d.string(forKey: "lastKnownTimeZoneID").flatMap(TimeZone.init(identifier:)) ?? .current
        return (CLLocationCoordinate2D(latitude: lat, longitude: lon), tz)
    }

    static func timeText(_ date: Date, _ timeZone: TimeZone) -> String {
        DisplayFormat.time(date, timeZone: timeZone, locale: LocalizationManager.shared.locale)
    }

    static func remainingText(from now: Date, to date: Date) -> String {
        let total = max(0, Int(date.timeIntervalSince(now) / 60))
        let h = total / 60, m = total % 60
        let loc = LocalizationManager.shared
        if h > 0 {
            return loc.tf("siri_remaining_hm", "%d saat %d dakika", h, m)
        }
        return loc.tf("siri_remaining_m", "%d dakika", m)
    }

    /// "Sıradaki namaz İkindi, saat 15:51. 41 dakika kaldı."
    static func nextPrayerAnswer(now: Date = Date()) -> String {
        let loc = LocalizationManager.shared
        guard let (coordinate, tz) = savedLocation() else {
            return loc.t("siri_no_location", fallback: "Önce uygulamayı bir kez açıp konumunu belirle.")
        }
        guard let next = PrayerCalculation.upcomingDays(2, coordinate: coordinate, timeZone: tz, from: now)
            .flatMap({ $0.times })
            .first(where: { $0.time > now }) else {
            return loc.t("siri_no_times", fallback: "Namaz vakitleri hesaplanamadı.")
        }
        return loc.tf("siri_next_answer", "Sıradaki namaz %@, saat %@. %@ kaldı.",
                      loc.x(next.name), timeText(next.time, tz), remainingText(from: now, to: next.time))
    }

    /// "Şu an kerahat vakti: Öğle kerahati, 12:54'e kadar." ya da sıradaki kerahat.
    static func kerahatAnswer(now: Date = Date()) -> String {
        let loc = LocalizationManager.shared
        guard let (coordinate, tz) = savedLocation() else {
            return loc.t("siri_no_location", fallback: "Önce uygulamayı bir kez açıp konumunu belirle.")
        }
        if let w = KerahatTimes.current(now: now, coordinate: coordinate, timeZone: tz) {
            return loc.tf("siri_kerahat_now", "Şu an kerahat vakti: %@. Yaklaşık %@'e kadar sürer.",
                          loc.t(w.kind.localizationKey, fallback: w.kind.turkishName), timeText(w.end, tz))
        }
        if let w = KerahatTimes.next(now: now, coordinate: coordinate, timeZone: tz) {
            return loc.tf("siri_kerahat_next", "Şu an kerahat vakti değil. Sıradaki kerahat yaklaşık %@ ile %@ arası.",
                          timeText(w.start, tz), timeText(w.end, tz))
        }
        return loc.t("siri_kerahat_none", fallback: "Şu an kerahat vakti değil. Bugün başka kerahat vakti yok.")
    }
}

struct NextPrayerIntent: AppIntent {
    static var title: LocalizedStringResource = "Sıradaki Namaz"
    static var description = IntentDescription("Sıradaki namazı ve kalan süreyi söyler.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: IntentDialog(stringLiteral: SiriPrayerInfo.nextPrayerAnswer()))
    }
}

struct KerahatNowIntent: AppIntent {
    static var title: LocalizedStringResource = "Kerahat Vakti mi?"
    static var description = IntentDescription("Şu an kerahat vakti olup olmadığını söyler.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: IntentDialog(stringLiteral: SiriPrayerInfo.kerahatAnswer()))
    }
}

struct SafaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NextPrayerIntent(),
            phrases: [
                "\(.applicationName) sıradaki namaz",
                "\(.applicationName) sıradaki namaz ne zaman",
                "\(.applicationName) next prayer"
            ],
            shortTitle: "Sıradaki Namaz",
            systemImageName: "clock"
        )
        AppShortcut(
            intent: KerahatNowIntent(),
            phrases: [
                "\(.applicationName) kerahat vakti mi",
                "\(.applicationName) kerahat"
            ],
            shortTitle: "Kerahat Vakti",
            systemImageName: "exclamationmark.triangle"
        )
    }
}
