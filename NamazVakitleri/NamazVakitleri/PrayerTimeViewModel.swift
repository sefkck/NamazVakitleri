import Foundation
import Combine
import CoreLocation
import Adhan

/// Verilen konum ve saat dilimine göre günün namaz vakitlerini
/// Diyanet yöntemiyle (CalculationMethod.turkey) hesaplar ve
/// bir sonraki vakte kalan süreyi her saniye günceller. Günün son
/// namazı (Yatsı) geçtiğinde yarının İmsak'ına geri sayım yapar.
final class PrayerTimeViewModel: ObservableObject {

    @Published var prayerTimes: DayPrayerTimes?
    @Published var nextPrayerName: String = "-"
    @Published var remainingTimeText: String = "--:--:--"
    /// Widget'a aktarmak için bir sonraki vaktin tam tarihi.
    @Published var nextPrayerDate: Date?
    /// Bu konum için vakit hesaplanamıyorsa (ör. kutup bölgesi) true.
    @Published var calculationFailed = false

    private var timer: Timer?
    private var lastCoordinate: CLLocationCoordinate2D?
    private var timeZone: TimeZone = .current
    /// Yatsı'dan sonra her saniye yeniden hesaplamamak için yarının vakitleri.
    private var tomorrowTimes: DayPrayerTimes?
    /// Vakitlerin hesaplandığı takvim günü (konumun saat diliminde, "yyyy-MM-dd").
    private var computedDayKey: String?

    /// Konum bilgisi geldiğinde veya değiştiğinde çağrılır.
    func start(coordinate: CLLocationCoordinate2D, timeZone: TimeZone) {
        self.lastCoordinate = coordinate
        self.timeZone = timeZone
        recalculate()

        timer?.invalidate()
        // .common modu: kullanıcı ekranı kaydırırken de geri sayım dursun istemiyoruz.
        let newTimer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    private func recalculate() {
        guard let coordinate = lastCoordinate else { return }
        let now = DebugClock.now
        prayerTimes = computeTimes(for: now, coordinate: coordinate)
        computedDayKey = Self.dayKey(now, timeZone: timeZone)
        tomorrowTimes = nil
        calculationFailed = prayerTimes == nil
        tick()
    }

    private func computeTimes(for date: Date, coordinate: CLLocationCoordinate2D) -> DayPrayerTimes? {
        PrayerCalculation.times(on: date, coordinate: coordinate, timeZone: timeZone)
    }

    private func tick() {
        guard let times = prayerTimes else { return }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        // Gün değiştiyse (gece yarısını geçtiysek) vakitleri yeniden hesapla.
        // Eskiden "İmsak bugün mü?" diye bakılıyordu. Telefonun saat dilimi
        // konumunkinden çok farklıysa (ör. İstanbul saatindeki telefon, Sidney
        // konumu) İmsak hiçbir zaman "bugün" çıkmıyor, recalculate ↔ tick
        // sonsuz döngüye girip uygulama çöküyordu. Artık takvim gününe bakılıyor.
        if Self.dayKey(DebugClock.now, timeZone: timeZone) != computedDayKey {
            recalculate()
            return
        }

        if let next = times.nextPrayer(at: DebugClock.now) {
            nextPrayerName = displayName(for: next)
            let nextTime = times.time(for: next)
            nextPrayerDate = nextTime
            let diff = max(0, nextTime.timeIntervalSince(DebugClock.now))
            remainingTimeText = format(diff)
        } else {
            // Bugünün son namazı (Yatsı) geçti - yarının İmsak'ına say
            if tomorrowTimes == nil,
               let tomorrow = calendar.date(byAdding: .day, value: 1, to: DebugClock.now),
               let coordinate = lastCoordinate {
                tomorrowTimes = computeTimes(for: tomorrow, coordinate: coordinate)
            }
            if let tomorrowTimes {
                nextPrayerName = "Yarın İmsak"
                nextPrayerDate = tomorrowTimes.fajr
                let diff = max(0, tomorrowTimes.fajr.timeIntervalSince(DebugClock.now))
                remainingTimeText = format(diff)
            } else {
                nextPrayerName = "Yatsı sonrası"
                nextPrayerDate = nil
                remainingTimeText = "--:--:--"
            }
        }
    }

    static func dayKey(_ date: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private func format(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    private func displayName(for prayer: Prayer) -> String {
        switch prayer {
        case .fajr: return "İmsak"
        case .sunrise: return "Güneş"
        case .dhuhr: return "Öğle"
        case .asr: return "İkindi"
        case .maghrib: return "Akşam"
        case .isha: return "Yatsı"
        }
    }

    deinit {
        timer?.invalidate()
    }
}
