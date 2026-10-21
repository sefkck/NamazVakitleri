import Foundation
import CoreLocation
import Adhan

/// Kerahat (namaz kılınması mekruh olan) vakitleri.
/// Diyanet'in resmi bir dakika tablosu yok; Türkiye'deki takvimlerde yerleşmiş
/// uygulama her biri için yaklaşık 45 dakikadır:
/// - İşrak: güneş doğduktan sonraki 45 dk
/// - İstiva: öğle vaktinden önceki ~10 dk (güneş tam tepedeyken; bir imamın
///   düzeltmesiyle 45 dk'dan kısaltıldı — istiva kısa bir andır)
/// - İsfirar: akşamdan (güneş batışı) önceki 45 dk
/// Ekranda bu yüzden "yaklaşık" diye gösterilir.
enum KerahatTimes {
    static let minutes: TimeInterval = 45 * 60
    static let istivaMinutes: TimeInterval = 10 * 60

    enum Kind: String {
        case israk, istiva, isfirar

        var turkishName: String {
            switch self {
            case .israk: return "Sabah kerahati (güneş doğuşu)"
            case .istiva: return "Öğle kerahati (istiva)"
            case .isfirar: return "Akşam kerahati (güneş batışı öncesi)"
            }
        }

        var localizationKey: String { "kerahat_\(rawValue)" }
    }

    struct Window: Equatable {
        let kind: Kind
        let start: Date
        let end: Date

        func contains(_ date: Date) -> Bool { date >= start && date < end }
    }

    static func windows(sunrise: Date, dhuhr: Date, maghrib: Date) -> [Window] {
        [
            Window(kind: .israk, start: sunrise, end: sunrise.addingTimeInterval(minutes)),
            Window(kind: .istiva, start: dhuhr.addingTimeInterval(-istivaMinutes), end: dhuhr),
            Window(kind: .isfirar, start: maghrib.addingTimeInterval(-minutes), end: maghrib)
        ]
    }

    static func windows(for times: DayPrayerTimes) -> [Window] {
        windows(sunrise: times.sunrise, dhuhr: times.dhuhr, maghrib: times.maghrib)
    }

    /// Şu an bir kerahat vaktindeyse o vakit; değilse nil.
    static func current(now: Date = Date(), coordinate: CLLocationCoordinate2D, timeZone: TimeZone) -> Window? {
        guard let today = PrayerCalculation.times(on: now, coordinate: coordinate, timeZone: timeZone) else { return nil }
        return windows(for: today).first { $0.contains(now) }
    }

    /// Bugünün (henüz bitmemiş) sıradaki kerahat vakti.
    static func next(now: Date = Date(), coordinate: CLLocationCoordinate2D, timeZone: TimeZone) -> Window? {
        guard let today = PrayerCalculation.times(on: now, coordinate: coordinate, timeZone: timeZone) else { return nil }
        return windows(for: today).first { $0.end > now }
    }
}
