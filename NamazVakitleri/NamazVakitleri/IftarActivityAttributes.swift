import ActivityKit
import Foundation

/// İftar / sahur canlı etkinliği (kilit ekranı + Dynamic Island).
/// Hem uygulamada hem widget hedefinde derlenir.
struct IftarActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// true: iftara (akşam) kalan; false: sahurun bitişine (imsak) kalan.
        var isIftar: Bool
        var start: Date
        var target: Date
    }

    var cityName: String
    var timeZoneID: String

    var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }
}
