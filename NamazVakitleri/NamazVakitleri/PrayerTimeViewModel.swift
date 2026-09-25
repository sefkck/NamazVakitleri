import Foundation
import Combine
import CoreLocation
import Adhan

/// Verilen konum ve saat dilimine göre günün namaz vakitlerini
/// Diyanet yöntemiyle (CalculationMethod.turkey) hesaplar ve
/// bir sonraki vakte kalan süreyi her saniye günceller. Günün son
/// namazı (Yatsı) geçtiğinde yarının İmsak'ına geri sayım yapar.
final class PrayerTimeViewModel: ObservableObject {

    @Published var prayerTimes: PrayerTimes?
    @Published var nextPrayerName: String = "-"
    @Published var remainingTimeText: String = "--:--:--"

    private var timer: Timer?
    private var lastCoordinate: CLLocationCoordinate2D?
    private var timeZone: TimeZone = .current

    /// Konum bilgisi geldiğinde veya değiştiğinde çağrılır.
    func start(coordinate: CLLocationCoordinate2D, timeZone: TimeZone) {
        self.lastCoordinate = coordinate
        self.timeZone = timeZone
        recalculate()

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func recalculate() {
        guard let coordinate = lastCoordinate else { return }
        prayerTimes = computeTimes(for: Date(), coordinate: coordinate)
        tick()
    }

    private func computeTimes(for date: Date, coordinate: CLLocationCoordinate2D) -> PrayerTimes? {
        let coordinates = Coordinates(latitude: coordinate.latitude, longitude: coordinate.longitude)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)

        // Diyanet yöntemine en yakın yaklaşım + Türkiye'de yaygın
        // ikindi hesabı (Şafi/standart, tek gölge boyu).
        var params = CalculationMethod.turkey.params
        params.madhab = .shafi

        return PrayerTimes(coordinates: coordinates, date: components, calculationParameters: params)
    }

    private func tick() {
        guard let times = prayerTimes else { return }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        // Gün değiştiyse (gece yarısını geçtiysek) vakitleri yeniden hesapla
        if !calendar.isDateInToday(times.fajr) {
            recalculate()
            return
        }

        if let next = times.nextPrayer() {
            nextPrayerName = displayName(for: next)
            let nextTime = times.time(for: next)
            let diff = max(0, nextTime.timeIntervalSinceNow)
            remainingTimeText = format(diff)
        } else {
            // Bugünün son namazı (Yatsı) geçti - yarının İmsak'ına say
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()),
               let coordinate = lastCoordinate,
               let tomorrowTimes = computeTimes(for: tomorrow, coordinate: coordinate) {
                nextPrayerName = "Yarın İmsak"
                let diff = max(0, tomorrowTimes.fajr.timeIntervalSinceNow)
                remainingTimeText = format(diff)
            } else {
                nextPrayerName = "Yatsı sonrası"
                remainingTimeText = "--:--:--"
            }
        }
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
        default: return "Yatsı sonrası"
        }
    }

    deinit {
        timer?.invalidate()
    }
}
