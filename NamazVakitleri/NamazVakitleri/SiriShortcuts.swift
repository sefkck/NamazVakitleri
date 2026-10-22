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

/// Siri'de söylenebilen vakit adları ("Safa öğle namazı kaçta").
enum SiriPrayer: String, AppEnum {
    case imsak, gunes, ogle, ikindi, aksam, yatsi

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Vakit"
    static var caseDisplayRepresentations: [SiriPrayer: DisplayRepresentation] = [
        .imsak: DisplayRepresentation(title: "İmsak", synonyms: ["sabah", "sabah namazı", "imsak vakti", "fajr"]),
        .gunes: DisplayRepresentation(title: "Güneş", synonyms: ["güneş doğuşu", "sunrise"]),
        .ogle: DisplayRepresentation(title: "Öğle", synonyms: ["öğle namazı", "öğlen", "dhuhr"]),
        .ikindi: DisplayRepresentation(title: "İkindi", synonyms: ["ikindi namazı", "asr"]),
        .aksam: DisplayRepresentation(title: "Akşam", synonyms: ["akşam namazı", "iftar", "maghrib"]),
        .yatsi: DisplayRepresentation(title: "Yatsı", synonyms: ["yatsı namazı", "isha"])
    ]

    var turkishName: String {
        switch self {
        case .imsak: return "İmsak"
        case .gunes: return "Güneş"
        case .ogle: return "Öğle"
        case .ikindi: return "İkindi"
        case .aksam: return "Akşam"
        case .yatsi: return "Yatsı"
        }
    }
}

extension SiriPrayerInfo {
    /// "Bugün Öğle 12:54." (geçtiyse yarınki de söylenir)
    static func prayerTimeAnswer(_ prayer: SiriPrayer, now: Date = Date()) -> String {
        let loc = LocalizationManager.shared
        guard let (coordinate, tz) = savedLocation() else {
            return loc.t("siri_no_location", fallback: "Önce uygulamayı bir kez açıp konumunu belirle.")
        }
        let days = PrayerCalculation.upcomingDays(2, coordinate: coordinate, timeZone: tz, from: now)
        guard let today = days.first?.times.first(where: { $0.name == prayer.turkishName }) else {
            return loc.t("siri_no_times", fallback: "Namaz vakitleri hesaplanamadı.")
        }
        if today.time > now {
            return loc.tf("siri_prayer_today", "Bugün %@ vakti saat %@. %@ kaldı.",
                          loc.x(prayer.turkishName), timeText(today.time, tz), remainingText(from: now, to: today.time))
        }
        let tomorrow = days.dropFirst().first?.times.first(where: { $0.name == prayer.turkishName })
        return loc.tf("siri_prayer_passed", "Bugün %@ vakti saat %@ idi. Yarın saat %@.",
                      loc.x(prayer.turkishName), timeText(today.time, tz), tomorrow.map { timeText($0.time, tz) } ?? "—")
    }

    /// "Bugünkü vakitler: İmsak 05:50, Güneş 07:15, …"
    static func todayTimesAnswer(now: Date = Date()) -> String {
        let loc = LocalizationManager.shared
        guard let (coordinate, tz) = savedLocation(),
              let today = PrayerCalculation.upcomingDays(1, coordinate: coordinate, timeZone: tz, from: now).first else {
            return loc.t("siri_no_location", fallback: "Önce uygulamayı bir kez açıp konumunu belirle.")
        }
        let list = today.times.map { "\(loc.x($0.name)) \(timeText($0.time, tz))" }.joined(separator: ", ")
        return loc.tf("siri_today_list", "Bugünkü vakitler: %@.", list)
    }
}

struct PrayerTimeIntent: AppIntent {
    static var title: LocalizedStringResource = "Vakit Kaçta?"
    static var description = IntentDescription("Seçilen vaktin bugünkü saatini söyler.")

    @Parameter(title: "Vakit")
    var prayer: SiriPrayer

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: IntentDialog(stringLiteral: SiriPrayerInfo.prayerTimeAnswer(prayer)))
    }
}

struct TodayTimesIntent: AppIntent {
    static var title: LocalizedStringResource = "Bugünkü Vakitler"
    static var description = IntentDescription("Bugünün bütün namaz vakitlerini söyler.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: IntentDialog(stringLiteral: SiriPrayerInfo.todayTimesAnswer()))
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
        AppShortcut(
            intent: PrayerTimeIntent(),
            phrases: [
                "\(.applicationName) \(\.$prayer) kaçta",
                "\(.applicationName) \(\.$prayer) namazı kaçta",
                "\(.applicationName) \(\.$prayer) vakti",
                "\(.applicationName) \(\.$prayer) ne zaman",
                "\(.applicationName) \(\.$prayer) namazı saat kaçta",
                "\(.applicationName) when is \(\.$prayer)"
            ],
            shortTitle: "Vakit Kaçta?",
            systemImageName: "sun.max"
        )
        AppShortcut(
            intent: TodayTimesIntent(),
            phrases: [
                "\(.applicationName) bugünkü vakitler",
                "\(.applicationName) namaz vakitleri",
                "\(.applicationName) bugün namaz vakitleri",
                "\(.applicationName) today's prayer times"
            ],
            shortTitle: "Bugünkü Vakitler",
            systemImageName: "list.bullet"
        )
    }
}
