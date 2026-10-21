import Foundation

/// "Şimdi". DEBUG derlemede ekran testleri için başka bir an verilebilir:
/// -uiTestDate 2027-02-15T14:00 (konumun saat dilimine bakılmaz, cihaz saatine göre).
/// App Store sürümünde her zaman gerçek saat.
enum DebugClock {
    static var now: Date {
        #if DEBUG
        if let text = UserDefaults.standard.string(forKey: "uiTestDate") {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "yyyy-MM-dd'T'HH:mm"
            if let date = f.date(from: text) { return date }
        }
        #endif
        return Date()
    }
}
