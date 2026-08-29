import Foundation
import CoreLocation
import Adhan
import Foundation
import Combine
import CoreLocation
import Adhan

/// Verilen konum ve saat dilimine göre günün namaz vakitlerini
/// Diyanet yöntemiyle (CalculationMethod.turkey) hesaplar ve
/// bir sonraki vakte kalan süreyi her saniye günceller.
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

        let coordinates = Coordinates(latitude: coordinate.latitude, longitude: coordinate.longitude)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: Date())

        // Diyanet yöntemine en yakın yaklaşım + Türkiye'de yaygın
        // ikindi hesabı (Şafi/standart, tek gölge boyu).
        var params = CalculationMethod.turkey.params
        params.madhab = .shafi

        prayerTimes = PrayerTimes(coordinates: coordinates, date: components, calculationParameters: params)
        tick()
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

        guard let next = times.nextPrayer() else {
            nextPrayerName = "Yatsı sonrası"
            remainingTimeText = "--:--:--"
            return
        }

        nextPrayerName = displayName(for: next)

        let nextTime = times.time(for: next)
        let diff = max(0, nextTime.timeIntervalSinceNow)
        remainingTimeText = format(diff)
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
