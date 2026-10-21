import Foundation
import WatchConnectivity
import CoreLocation
import Combine

/// Saat tarafı: iPhone'dan gelen konum/dil/ayar bilgisini aynı anahtarlarla
/// saklar; böylece paylaşılan hesaplama kodu (PrayerCalculation) aynen çalışır.
final class WatchStore: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchStore()

    @Published private(set) var revision = 0

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    var location: (CLLocationCoordinate2D, TimeZone)? {
        let d = UserDefaults.standard
        let lat = d.double(forKey: "lastKnownLatitude"), lon = d.double(forKey: "lastKnownLongitude")
        guard lat != 0 || lon != 0 else { return nil }
        let tz = d.string(forKey: "lastKnownTimeZoneID").flatMap(TimeZone.init(identifier:)) ?? .current
        return (CLLocationCoordinate2D(latitude: lat, longitude: lon), tz)
    }

    var cityName: String { UserDefaults.standard.string(forKey: "lastKnownCityName") ?? "" }

    static func apply(_ ctx: [String: Any]) {
        let d = UserDefaults.standard
        if let v = ctx["lat"] as? Double { d.set(v, forKey: "lastKnownLatitude") }
        if let v = ctx["lon"] as? Double { d.set(v, forKey: "lastKnownLongitude") }
        if let v = ctx["tz"] as? String { d.set(v, forKey: "lastKnownTimeZoneID") }
        if let v = ctx["city"] as? String, !v.isEmpty { d.set(v, forKey: "lastKnownCityName") }
        if let v = ctx["method"] as? String { d.set(v, forKey: PrayerCalculation.methodKey) }
        for p in ["fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha"] {
            if let v = ctx["adj_\(p)"] as? Int { d.set(v, forKey: "prayer_manual_adjust_\(p)") }
        }
        if let v = ctx["lang"] as? String, let lang = AppLanguage(rawValue: v) {
            LocalizationManager.shared.language = lang
        }
    }

    private func receive(_ ctx: [String: Any]) {
        DispatchQueue.main.async {
            Self.apply(ctx)
            self.revision += 1
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if !session.receivedApplicationContext.isEmpty { receive(session.receivedApplicationContext) }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        receive(applicationContext)
    }
}
