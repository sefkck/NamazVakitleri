import Foundation
import Adhan
import CoreLocation

/// Namaz vakti hesaplama parametrelerini tek bir yerden üretir - hem
/// PrayerTimeViewModel (ekranda gösterim) hem NotificationManager
/// (bildirim planlama) aynı ayarları kullanır, aralarında tutarsızlık
/// olmaz.
///
/// ÖNEMLİ NOT: Açık kaynak Adhan kütüphanesinin "Turkey" yöntemi,
/// Diyanet İşleri'nin YAYINLADIĞI resmi tabloları çekmez (böyle genel
/// kullanıma açık resmi bir API mevcut değil) - astronomik açılara
/// dayalı bir YAKLAŞIKLIKTIR. Burada, kütüphanenin referans
/// uygulamasında (adhan-js) Türkiye için kullanılan tam düzeltme
/// değerlerini (18°/17° açı + gün doğumu/öğle/ikindi/akşam dakika
/// düzeltmeleri) açıkça garantiye alıyoruz. Yine de gerçek Diyanet
/// tablosuyla 1-3 dakikalık fark kalabilir - bu yüzden kullanıcının
/// kendi camisine göre dakika bazında ince ayar yapabildiği bir
/// mekanizma da ekledik (bkz. `manualAdjustments`).
enum PrayerCalculation {
    static func buildParams() -> CalculationParameters {
        // Kütüphanenin kendi hazır "Turkey" ayarını temel alıyoruz (bu
        // satır projenin başından beri sorunsuz derleniyor) - zaten
        // 18°/17° açılarını ve Türkiye'ye özgü düzeltmeleri içeriyor.
        // Üzerine sadece ikindi hesabını ve kullanıcının manuel ince
        // ayarını ekliyoruz.
        var params = selectedMethod.adhanMethod.params
        params.madhab = .shafi
        params.adjustments = manualAdjustments()
        return params
    }

    // MARK: - Hesaplama yöntemi (yurt dışındaki camilerle uyum için)

    enum Method: String, CaseIterable, Identifiable {
        case diyanet, isna, mwl, ummAlQura
        var id: String { rawValue }
        var adhanMethod: CalculationMethod {
            switch self {
            case .diyanet: return .turkey
            case .isna: return .northAmerica
            case .mwl: return .muslimWorldLeague
            case .ummAlQura: return .ummAlQura
            }
        }
        var titleKey: String { "method_\(rawValue)" }
        var turkishTitle: String {
            switch self {
            case .diyanet: return "Diyanet (Türkiye)"
            case .isna: return "ISNA (Kuzey Amerika)"
            case .mwl: return "Müslüman Dünya Birliği (Avrupa)"
            case .ummAlQura: return "Ümmü'l-Kurâ (Mekke)"
            }
        }
    }

    static let methodKey = "calculation_method"

    static var selectedMethod: Method {
        Method(rawValue: UserDefaults.standard.string(forKey: methodKey) ?? "") ?? .diyanet
    }

    static func setMethod(_ method: Method) {
        UserDefaults.standard.set(method.rawValue, forKey: methodKey)
        NotificationCenter.default.post(name: adjustmentsDidChange, object: nil)
    }

    // MARK: - Kullanıcının manuel ince ayarı

    private static func key(_ prayer: String) -> String { "prayer_manual_adjust_\(prayer)" }

    static func manualAdjustment(for prayer: String) -> Int {
        UserDefaults.standard.integer(forKey: key(prayer))
    }

    static func setManualAdjustment(_ minutes: Int, for prayer: String) {
        UserDefaults.standard.set(minutes, forKey: key(prayer))
        // Ana ekran bunu dinleyip vakitleri hemen yeniden hesaplar.
        NotificationCenter.default.post(name: adjustmentsDidChange, object: nil)
    }

    /// Kullanıcı dakika ince ayarını değiştirdiğinde yayınlanır.
    static let adjustmentsDidChange = Notification.Name("PrayerCalculation.adjustmentsDidChange")

    // MARK: - Ortak hesaplama yardımcıları

    /// Verilen günün (konumun saat dilimindeki takvim günü) namaz vakitleri.
    static func times(on date: Date, coordinate: CLLocationCoordinate2D, timeZone: TimeZone) -> DayPrayerTimes? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let coords = Coordinates(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var params = buildParams()
        params.rounding = .none   // yuvarlamayı aşağıda, mevsim düzeltmesinden sonra yapıyoruz
        guard let raw = PrayerTimes(coordinates: coords, date: components, calculationParameters: params) else { return nil }
        let dayOfYear = Double(calendar.ordinality(of: .day, in: .year, for: date) ?? 1)
        let diyanet = selectedMethod == .diyanet
        func fixed(_ d: Date, _ k: [Double]?) -> Date {
            // Mevsim düzeltmesi sadece Diyanet yöntemi içindir.
            let shifted = (diyanet ? k : nil).map { d.addingTimeInterval(seasonalCorrection(k: $0, dayOfYear: dayOfYear)) } ?? d
            return (shifted.timeIntervalSinceReferenceDate / 60).rounded().times60
        }
        return DayPrayerTimes(fajr: fixed(raw.fajr, nil), sunrise: fixed(raw.sunrise, nil), dhuhr: fixed(raw.dhuhr, nil),
                              asr: fixed(raw.asr, asrK), maghrib: fixed(raw.maghrib, maghribK), isha: fixed(raw.isha, ishaK))
    }

    // MARK: - Diyanet tablosuna mevsim düzeltmesi
    //
    // Adhan'ın "turkey" yöntemi Diyanet'e yakındır ama İkindi/Akşam/Yatsı'da
    // mevsime göre ±1–2 dk sapar (Ağu–Kas Diyanet ~1 dk geç, Oca–May ~1 dk erken).
    // Katsayılar Diyanet'in Ankara 2026–2027 tablosundan (43 gün) en küçük kareler
    // ile bulundu: fark(sn) = a + b·cos(w) + c·sin(w) + d·cos(2w) + e·sin(2w), w = 2π·gün/365,25.
    // İstanbul (7 gün) ve Erzurum'da (hiç görülmemiş veri) tam dakika tuttu.
    // Ayrıntı: CLAUDE CODE/diyanet_fit_2026-10-21.md
    static let asrK: [Double] = [9.23, -16.17, -61.97, -16.56, -4.41]
    static let maghribK: [Double] = [2.03, -16.57, -53.49, -17.14, 2.58]
    static let ishaK: [Double] = [8.97, -22.10, -68.60, -7.86, 17.49]

    static func seasonalCorrection(k: [Double], dayOfYear: Double) -> TimeInterval {
        let w = 2 * Double.pi * dayOfYear / 365.25
        return k[0] + k[1] * cos(w) + k[2] * sin(w) + k[3] * cos(2 * w) + k[4] * sin(2 * w)
    }

    /// Bugünden başlayarak `days` günün altı vaktini (İmsak, Güneş, Öğle,
    /// İkindi, Akşam, Yatsı) üretir. Widget, uygulama açılmasa da doğru
    /// günü gösterebilsin diye bunu birkaç gün ileri kaydediyoruz.
    static func upcomingDays(_ days: Int, coordinate: CLLocationCoordinate2D, timeZone: TimeZone, from start: Date = Date()) -> [PrayerWidgetData.DayTimes] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let today = calendar.startOfDay(for: start)
        return (0..<days).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let t = times(on: day, coordinate: coordinate, timeZone: timeZone) else { return nil }
            let list: [(String, Date)] = [
                ("İmsak", t.fajr), ("Güneş", t.sunrise), ("Öğle", t.dhuhr),
                ("İkindi", t.asr), ("Akşam", t.maghrib), ("Yatsı", t.isha)
            ]
            return PrayerWidgetData.DayTimes(
                dayStart: day,
                times: list.map { PrayerWidgetData.DailyPrayerTime(name: $0.0, time: $0.1) }
            )
        }
    }

    private static func manualAdjustments() -> PrayerAdjustments {
        PrayerAdjustments(
            fajr: manualAdjustment(for: "fajr"),
            sunrise: manualAdjustment(for: "sunrise"),
            dhuhr: manualAdjustment(for: "dhuhr"),
            asr: manualAdjustment(for: "asr"),
            maghrib: manualAdjustment(for: "maghrib"),
            isha: manualAdjustment(for: "isha")
        )
    }
}

private extension Double {
    /// Dakika sayısından tarihe (en yakın dakikaya yuvarlanmış).
    var times60: Date { Date(timeIntervalSinceReferenceDate: self * 60) }
}

/// Bir günün altı vakti (Diyanet'e göre düzeltilmiş ve dakikaya yuvarlanmış).
/// Adhan'ın `PrayerTimes`'ı ile aynı alan adlarını kullanır.
struct DayPrayerTimes: Equatable {
    let fajr: Date
    let sunrise: Date
    let dhuhr: Date
    let asr: Date
    let maghrib: Date
    let isha: Date

    func time(for prayer: Prayer) -> Date {
        switch prayer {
        case .fajr: return fajr
        case .sunrise: return sunrise
        case .dhuhr: return dhuhr
        case .asr: return asr
        case .maghrib: return maghrib
        case .isha: return isha
        }
    }

    /// `date`'ten sonraki ilk vakit; Yatsı geçtiyse nil.
    func nextPrayer(at date: Date = Date()) -> Prayer? {
        let all: [Prayer] = [.fajr, .sunrise, .dhuhr, .asr, .maghrib, .isha]
        return all.first { time(for: $0) > date }
    }
}
