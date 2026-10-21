import Foundation

/// "Şimdi". DEBUG derlemede ekran testleri için başka bir an verilebilir:
/// -uiTestDate 2027-02-15T14:00 (cihaz saatine göre). Verilen andan itibaren
/// saat normal akar (geri sayımlar çalışır). App Store sürümünde her zaman gerçek saat.
enum DebugClock {
    #if DEBUG
    private static let launch = Date()
    private static let anchor: Date? = {
        guard let text = UserDefaults.standard.string(forKey: "uiTestDate") else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return f.date(from: text)
    }()
    #endif

    static var isOverridden: Bool {
        #if DEBUG
        return anchor != nil
        #else
        return false
        #endif
    }

    static var now: Date {
        #if DEBUG
        if let anchor { return anchor.addingTimeInterval(Date().timeIntervalSince(launch)) }
        #endif
        return Date()
    }
}
