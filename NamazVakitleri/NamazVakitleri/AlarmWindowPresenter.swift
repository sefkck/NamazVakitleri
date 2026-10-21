import SwiftUI
import UIKit

/// Alarm ekranını, uygulamanın üstünde duran AYRI bir pencerede gösterir.
/// Eskiden alarm, kök görünümden `.fullScreenCover` ile açılıyordu. Ayarlar
/// gibi bir pencere (sheet) açıkken iOS alarmı gösterebilmek için o pencereyi
/// kapatıyordu; "Kıldım"a basınca kullanıcı Ayarlar'dan atılıyordu. Ayrı
/// pencere alttaki ekranlara hiç dokunmaz.
final class AlarmWindowPresenter {
    static let shared = AlarmWindowPresenter()

    private var window: UIWindow?

    var isVisible: Bool { window != nil }

    /// Bildirim yöneticisindeki duruma göre alarm penceresini açar ya da kapatır.
    func sync() {
        if NotificationManager.shared.activeAlarmTitle != nil {
            show()
        } else {
            hide()
        }
    }

    private func show() {
        guard window == nil, let scene = Self.activeScene() else { return }
        let host = UIHostingController(rootView: AlarmWindowContent())
        host.view.backgroundColor = .clear
        let newWindow = UIWindow(windowScene: scene)
        newWindow.windowLevel = .alert + 1
        newWindow.rootViewController = host
        newWindow.makeKeyAndVisible()
        window = newWindow
    }

    private func hide() {
        guard let window else { return }
        window.isHidden = true
        self.window = nil
        // Klavye ve dokunuşlar yeniden uygulamanın kendi penceresine gitsin.
        Self.activeScene()?.windows.first { $0.windowLevel == .normal }?.makeKey()
    }

    private static func activeScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }
}

/// Alarm penceresinin içeriği. Temayı ve yazı yönünü uygulamayla aynı tutar.
private struct AlarmWindowContent: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @ObservedObject private var notificationManager = NotificationManager.shared
    @AppStorage("isDarkTheme") private var isDarkTheme: Bool = false

    var body: some View {
        AlarmOverlayView(
            title: notificationManager.activeAlarmTitle ?? loc.t("alarm_default_title", fallback: "Namaz Vakti"),
            message: notificationManager.activeAlarmBody ?? "",
            onDismiss: { notificationManager.markActiveAlarmPrayed() },
            onSnooze: {
                let title = notificationManager.activeAlarmTitle ?? loc.t("alarm_default_title", fallback: "Namaz Vakti")
                var info: [AnyHashable: Any] = [:]
                if let p = notificationManager.activeAlarmPrayer {
                    info = [NotificationManager.prayerInfoKey: p.name, NotificationManager.dayInfoKey: p.dayKey]
                }
                notificationManager.dismissActiveAlarm()
                notificationManager.scheduleSnooze(title: title, userInfo: info)
            }
        )
        .preferredColorScheme(isDarkTheme ? .dark : .light)
        .environment(\.layoutDirection, loc.language.isRightToLeft ? .rightToLeft : .leftToRight)
    }
}
