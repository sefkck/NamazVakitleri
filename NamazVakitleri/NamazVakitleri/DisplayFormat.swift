import Foundation

/// Saat ve mesafe yazımı telefonun kendi ayarlarına uyar:
/// - Telefon 12 saat kullanıyorsa "6:14 PM", 24 saat kullanıyorsa "18:14".
/// - Ülke mil kullanıyorsa (ABD, İngiltere) "0.2 mi", yoksa "350 m" / "2.3 km".
/// Bu dosya hem uygulamada hem widget'ta derlenir.
enum DisplayFormat {
    /// Telefonun saat biçimi 12 saatlik mi? (Ayarlar > Genel > Tarih ve Saat)
    static var uses12Hour: Bool {
        (DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: Locale.current) ?? "").contains("a")
    }

    /// Mesafe mil ile mi yazılmalı?
    static var usesMiles: Bool {
        let system = Locale.current.measurementSystem
        return system == .us || system == .uk
    }

    /// Vakit saati. `compact`: 12 saatte "AM/PM" yazılmaz (dar tablolar için).
    static func time(_ date: Date, timeZone: TimeZone, locale: Locale = Locale.current,
                     seconds: Bool = false, compact: Bool = false) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = timeZone
        if uses12Hour {
            f.dateFormat = (seconds ? "h:mm:ss" : "h:mm") + (compact ? "" : " a")
        } else {
            f.dateFormat = seconds ? "HH:mm:ss" : "HH:mm"
        }
        return f.string(from: date)
    }

    /// Kısa mesafe (camiler): "350 m" / "2.3 km" ya da "0.2 mi" / "1.4 mi".
    static func distance(meters: Double) -> String {
        if usesMiles {
            let miles = meters / 1609.344
            return miles < 0.1 ? String(format: "%.0f ft", meters * 3.28084) : "\(oneDecimal(miles)) mi"
        }
        return meters < 1000 ? String(format: "%.0f m", meters) : "\(oneDecimal(meters / 1000)) km"
    }

    /// Bir ondalık, telefonun bölge ayarına göre ("1,6" Almanya, "1.6" ABD).
    static func oneDecimal(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)))
    }

    /// Uzun mesafe (Kâbe'ye): "2.400 km" ya da "1,491 mi".
    static func longDistance(km: Double, kmUnit: String = "km") -> String {
        let value = usesMiles ? km / 1.609344 : km
        let number = value.formatted(.number.precision(.fractionLength(0)))
        return usesMiles ? "\(number) mi" : "\(number) \(kmUnit)"
    }
}
