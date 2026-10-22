import ActivityKit
import CoreLocation
import Foundation

/// İmsakiye ekranındaki anahtarla açılan iftar/sahur sayacı.
/// Sayaç kilit ekranında kendi kendine geri sayar; hedef vakit geçince
/// uygulama açıldığında ya da arka plan yenilemesinde sıradaki hedefe geçer.
enum IftarLiveActivity {
    static let enabledKey = "iftar_live_activity"

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    static var systemAllowed: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    /// İmsaktan önce → sahur (bugünkü imsak); gündüz → iftar; akşamdan sonra → yarınki imsak.
    static func nextTarget(now: Date, coordinate: CLLocationCoordinate2D, timeZone: TimeZone) -> (isIftar: Bool, target: Date)? {
        guard let today = PrayerCalculation.times(on: now, coordinate: coordinate, timeZone: timeZone) else { return nil }
        if now < today.fajr { return (false, today.fajr) }
        if now < today.maghrib { return (true, today.maghrib) }
        guard let tomorrow = PrayerCalculation.times(on: now.addingTimeInterval(24 * 3600), coordinate: coordinate, timeZone: timeZone) else { return nil }
        return (false, tomorrow.fajr)
    }

    static func setEnabled(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: enabledKey)
        if on { refresh() } else { stopAll() }
    }

    /// Açıksa sayacı başlatır ya da hedefi geçmişse sıradakine günceller.
    static func refresh(now: Date = Date()) {
        var on = isEnabled
        #if DEBUG
        // Ekran testi: -uiLiveActivity YES (ayar kaydedilmez)
        if UserDefaults.standard.bool(forKey: "uiLiveActivity") { on = true }
        #endif
        guard on else { stopAll(); return }
        guard systemAllowed,
              let (coordinate, tz) = NotificationManager.lastKnownLocation(),
              let next = nextTarget(now: now, coordinate: coordinate, timeZone: tz) else { return }
        let state = IftarActivityAttributes.ContentState(isIftar: next.isIftar, start: now, target: next.target)
        let content = ActivityContent(state: state, staleDate: next.target)
        // iOS 8 saat sonra etkinliği bitirir; bitmiş olanı güncellemek işe yaramaz.
        let running = Activity<IftarActivityAttributes>.activities.filter { $0.activityState == .active || $0.activityState == .stale }
        if running.isEmpty { stopAll() }
        if let current = running.first {
            guard current.content.state.target != next.target else { return }
            Task { await current.update(content) }
            return
        }
        let city = UserDefaults.standard.string(forKey: "lastKnownCityName") ?? ""
        _ = try? Activity.request(attributes: IftarActivityAttributes(cityName: city, timeZoneID: tz.identifier),
                                  content: content, pushType: nil)
    }

    static func stopAll() {
        for activity in Activity<IftarActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
