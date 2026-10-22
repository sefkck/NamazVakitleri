import AlarmKit
import Foundation

/// Gerçek alarmın (AlarmKit) ek bilgisi. Uygulama ve widget hedefinde derlenir:
/// widget, "Ertele" sonrası geri sayımı kilit ekranında gösterir.
nonisolated struct PrayerAlarmMetadata: AlarmMetadata {
    var prayerName: String
}
