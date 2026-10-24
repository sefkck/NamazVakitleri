import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Ana uygulama ile Widget Extension arasında veri paylaşımı için
/// kullanılan App Group deposu. Widget'lar ayrı bir process'te
/// çalıştığından normal UserDefaults.standard'ı GÖREMEZ - bu yüzden
/// "App Group" adlı paylaşımlı bir alan gerekiyor.
///
/// KURULUM (Xcode'da, kod dışında yapman gereken tek seferlik adım):
/// 1. Ana uygulama hedefi (NamazVakitleri) seçili, Signing & Capabilities
///    sekmesinde "+ Capability" > "App Groups" ekle.
/// 2. Yeni bir grup oluştur, adı tam olarak: group.com.kocaksefa.safa
///    (istersen farklı bir isim seç ama aşağıdaki `suiteName` ile
///    BİREBİR aynı olmalı).
/// 3. Widget Extension hedefini de oluşturduktan sonra (aşağıdaki not),
///    onun Signing & Capabilities'ine de AYNI App Group'u ekle - iki
///    hedefin de işaretli olması şart, yoksa veri paylaşılmaz.
enum PrayerWidgetData {
    static let appGroupID = "group.com.kocaksefa.safa"

    /// Widget kendi başına vakit hesaplayamadığı (Adhan kütüphanesi
    /// widget'a bağlı değil) için uygulama bu kadar gün ileriyi kaydeder.
    /// Böylece uygulama birkaç gün açılmasa da widget doğru günü gösterir.
    static let storedDayCount = 7

    private static let snapshotKey = "widget_snapshot_v2"
    private static let darkThemeKey = "isDarkTheme"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    struct DailyPrayerTime: Codable, Equatable {
        let name: String
        let time: Date
    }

    /// Bir takvim gününün altı vakti (İmsak, Güneş, Öğle, İkindi, Akşam, Yatsı).
    struct DayTimes: Codable, Equatable {
        /// Konumun saat dilimindeki gün başlangıcı (00:00).
        let dayStart: Date
        let times: [DailyPrayerTime]
    }

    struct Snapshot: Codable {
        let cityName: String
        let updatedAt: Date
        /// Vakitlerin gösterileceği saat dilimi (seçilen konumunki).
        let timeZoneID: String
        let days: [DayTimes]

        var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }
    }

    /// Ana uygulama, namaz vakitlerini her yeniden hesapladığında bunu
    /// çağırır ve widget'lara hemen yenilenmelerini söyler.
    static func save(cityName: String, timeZone: TimeZone, days: [DayTimes]) {
        guard !days.isEmpty else { return }
        // Değişen bir şey yoksa yazma ve widget'ı yenileme: WidgetKit'in
        // günlük yenileme hakkı sınırlı.
        if let current = load(),
           current.cityName == cityName,
           current.timeZoneID == timeZone.identifier,
           current.days == days {
            return
        }
        let snapshot = Snapshot(
            cityName: cityName,
            updatedAt: Date(),
            timeZoneID: timeZone.identifier,
            days: days
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: snapshotKey)
        reloadWidgets()
    }

    /// Widget bunu okuyarak son bilinen namaz vakti bilgisini gösterir.
    static func load() -> Snapshot? {
        guard let data = defaults?.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    // MARK: - Tema (uygulamanın kendi Aydınlık/Karanlık seçimi)

    static func saveDarkTheme(_ isDark: Bool) {
        guard defaults?.object(forKey: darkThemeKey) as? Bool != isDark else { return }
        defaults?.set(isDark, forKey: darkThemeKey)
        reloadWidgets()
    }

    /// Kullanıcının uygulamada seçtiği tema; hiç seçilmediyse nil
    /// (widget o zaman sistem görünümünü kullanır).
    static func storedDarkTheme() -> Bool? {
        defaults?.object(forKey: darkThemeKey) as? Bool
    }

    /// Widget zaman çizelgesinin bir adımı: `date` anından itibaren
    /// sıradaki vakit `nextName`/`nextDate`, "BUGÜN" listesi `today`.
    struct TimelineStep {
        let date: Date
        let nextName: String
        let nextDate: Date
        let today: [DailyPrayerTime]
    }

    /// Şu andan itibaren (en fazla `horizonDays` gün) her vakit ve her gün
    /// başlangıcı için bir adım üretir. Widget bunu kullanır; uygulama
    /// açılmasa da doğru gün ve doğru "sıradaki namaz" gösterilir.
    static func timelineSteps(from snapshot: Snapshot, now: Date = Date(), horizonDays: Double = 3) -> [TimelineStep] {
        let days = snapshot.days.sorted { $0.dayStart < $1.dayStart }
        let allTimes = days.flatMap { $0.times }.sorted { $0.time < $1.time }
        guard let lastTime = allTimes.last?.time, lastTime > now else { return [] }

        let horizon = now.addingTimeInterval(horizonDays * 24 * 3600)
        var boundaries: [Date] = [now]
        boundaries += allTimes.map(\.time).filter { $0 > now && $0 <= horizon }
        boundaries += days.map(\.dayStart).filter { $0 > now && $0 <= horizon }
        boundaries = Array(Set(boundaries)).sorted()

        var steps: [TimelineStep] = []
        for boundary in boundaries {
            guard let today = days.last(where: { $0.dayStart <= boundary }) else { continue }
            guard let next = allTimes.first(where: { $0.time > boundary }) else { break }
            let nextIsTomorrow = !today.times.contains { $0.time == next.time }
            steps.append(TimelineStep(
                date: boundary,
                nextName: nextIsTomorrow ? "Yarın İmsak" : next.name,
                nextDate: next.time,
                today: today.times
            ))
        }
        return steps
    }

    static func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
