import Foundation
import WatchConnectivity

/// iPhone → Apple Watch: konum, saat dilimi, şehir adı, dil ve hesaplama ayarları.
/// Saat vakitleri bu bilgilerle kendisi hesaplar; telefon yanında olmasa da çalışır.
final class WatchSync: NSObject, WCSessionDelegate {
    static let shared = WatchSync()

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Son bilinen konumu saate gönderir (saat eşli değilse sessizce geçer).
    func push() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        try? session.updateApplicationContext(Self.context())
    }

    static func context() -> [String: Any] {
        let d = UserDefaults.standard
        var ctx: [String: Any] = [
            "lat": d.double(forKey: "lastKnownLatitude"),
            "lon": d.double(forKey: "lastKnownLongitude"),
            "tz": d.string(forKey: "lastKnownTimeZoneID") ?? TimeZone.current.identifier,
            "city": d.string(forKey: "lastKnownCityName") ?? "",
            "lang": d.string(forKey: "appLanguage") ?? "tr",
            "method": d.string(forKey: PrayerCalculation.methodKey) ?? "diyanet",
            "sent": Date().timeIntervalSince1970
        ]
        for p in ["fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha"] {
            ctx["adj_\(p)"] = d.integer(forKey: "prayer_manual_adjust_\(p)")
        }
        return ctx
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if activationState == .activated { DispatchQueue.main.async { self.push() } }
    }
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}
