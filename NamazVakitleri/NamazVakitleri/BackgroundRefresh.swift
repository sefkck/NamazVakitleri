import Foundation
import BackgroundTasks

/// Uygulama günlerce açılmasa bile namaz alarmlarının ve widget
/// verisinin bitmemesi için iOS'tan düzenli arka plan çalışma süresi
/// ister. Her çalışmada son bilinen konumla:
/// - namaz bildirimlerini 7 gün ileriye yeniden planlar,
/// - widget'ın okuduğu 7 günlük vakit listesini yeniler.
/// iOS ne zaman çalıştıracağına kendisi karar verir (genelde birkaç saatte
/// bir). Bu yüzden ayrıca "alarmlar yakında duracak" güvenlik bildirimi var.
enum BackgroundRefresh {
    /// Info.plist > BGTaskSchedulerPermittedIdentifiers ile aynı olmalı.
    static let taskIdentifier = "com.kocaksefa.NamazVakitleri.refresh"

    /// Uygulama açılışında (App.init) bir kez çağrılır.
    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handle(refreshTask)
        }
    }

    /// Uygulama arka plana geçerken çağrılır.
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(_ task: BGAppRefreshTask) {
        // Bir sonrakini hemen iste ki zincir kopmasın.
        schedule()

        let finished = TaskFinisher(task)
        task.expirationHandler = { finished.complete(success: false) }

        DispatchQueue.main.async {
            refreshWidgetData()
            IftarLiveActivity.refresh()
            NotificationManager.shared.rescheduleFromLastKnownLocation {
                finished.complete(success: true)
            }
        }
    }

    /// Son bilinen konumla widget'ın 7 günlük vakit listesini yeniler.
    static func refreshWidgetData() {
        guard let (coordinate, timeZone) = NotificationManager.lastKnownLocation() else { return }
        let city = UserDefaults.standard.string(forKey: "lastKnownCityName") ?? ""
        PrayerWidgetData.save(
            cityName: city,
            timeZone: timeZone,
            days: PrayerCalculation.upcomingDays(PrayerWidgetData.storedDayCount, coordinate: coordinate, timeZone: timeZone)
        )
    }

    /// setTaskCompleted yalnızca bir kez çağrılsın diye.
    private final class TaskFinisher {
        private let task: BGTask
        private var done = false
        private let lock = NSLock()

        init(_ task: BGTask) { self.task = task }

        func complete(success: Bool) {
            lock.lock()
            defer { lock.unlock() }
            guard !done else { return }
            done = true
            task.setTaskCompleted(success: success)
        }
    }
}
