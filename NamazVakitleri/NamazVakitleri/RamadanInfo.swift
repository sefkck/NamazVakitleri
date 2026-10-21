import Foundation
import CoreLocation
import Adhan

/// Ramazan ayı bilgisi (Hicri takvim, Ümmü'l-Kurâ). Diyanet'in ilanı
/// bir gün farklı olabilir; bu yüzden ekranda "yaklaşık" bilgi olarak
/// kullanılır, kesin tarih için Dini Günler listesi esas alınır.
enum RamadanInfo {
    private static func hijri(_ timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .islamicUmmAlQura)
        calendar.timeZone = timeZone
        return calendar
    }

    /// Ramazan'ın kaçıncı günü (1...30); Ramazan değilse nil.
    static func dayOfRamadan(_ date: Date = Date(), timeZone: TimeZone = .current) -> Int? {
        let c = hijri(timeZone).dateComponents([.month, .day], from: date)
        return c.month == 9 ? c.day : nil
    }

    /// İçinde bulunulan ya da sıradaki Ramazan'ın günleri (Miladi gün başları).
    static func ramadanDays(around date: Date = Date(), timeZone: TimeZone = .current) -> [Date] {
        let calendar = hijri(timeZone)
        let c = calendar.dateComponents([.year, .month], from: date)
        guard let year = c.year, let month = c.month else { return [] }
        let targetYear = month > 9 ? year + 1 : year
        guard let start = calendar.date(from: DateComponents(year: targetYear, month: 9, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: start) else { return [] }
        return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: calendar.startOfDay(for: start)) }
    }

    enum FastingTarget: Equatable {
        case iftar(Date)   // bugünün akşam vakti (orucu açma)
        case sahur(Date)   // sıradaki imsak (sahurun bitişi)
    }

    /// Ramazan'da ana sayfada gösterilecek geri sayım hedefi.
    /// İmsak ile akşam arası → iftar; akşamdan sonra/imsaktan önce → sahur (imsak).
    static func fastingTarget(now: Date = Date(), coordinate: CLLocationCoordinate2D, timeZone: TimeZone) -> FastingTarget? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let today = PrayerCalculation.times(on: now, coordinate: coordinate, timeZone: timeZone) else { return nil }
        if now < today.fajr {
            return dayOfRamadan(today.fajr, timeZone: timeZone) != nil ? .sahur(today.fajr) : nil
        }
        if now < today.maghrib {
            return dayOfRamadan(now, timeZone: timeZone) != nil ? .iftar(today.maghrib) : nil
        }
        guard let tomorrowDate = calendar.date(byAdding: .day, value: 1, to: now),
              let tomorrow = PrayerCalculation.times(on: tomorrowDate, coordinate: coordinate, timeZone: timeZone) else { return nil }
        return dayOfRamadan(tomorrow.fajr, timeZone: timeZone) != nil ? .sahur(tomorrow.fajr) : nil
    }
}
