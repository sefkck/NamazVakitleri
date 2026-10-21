import SwiftUI
import UIKit
import StoreKit

struct RootView: View {
    @State private var showSplash = true
    @AppStorage("isDarkTheme") private var isDarkTheme: Bool = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome: Bool = false
    @ObservedObject private var notificationManager = NotificationManager.shared
    @ObservedObject private var loc = LocalizationManager.shared
    @StateObject private var onboardingLocationRequester = OnboardingLocationRequester()
    @Environment(\.requestReview) private var requestReview
    @State private var showNotificationPrimer = false

    init() {
        // Kullanıcı Ayarlar'dan hiç manuel seçim yapmadıysa (ilk kurulum),
        // uygulama telefonun o anki Karanlık/Aydınlık sistem ayarıyla
        // açılır. @AppStorage her okumada UserDefaults'tan taze veri
        // çektiği için burada init() içinde yazmak, ilk body render'ında
        // bile doğru temanın gelmesini sağlar (yanıp sönme olmaz).
        if UserDefaults.standard.object(forKey: "isDarkTheme") == nil {
            let systemPrefersDark = UITraitCollection.current.userInterfaceStyle == .dark
            UserDefaults.standard.set(systemPrefersDark, forKey: "isDarkTheme")
        }
    }

    var body: some View {
        ZStack {
            if !showSplash && hasSeenWelcome {
                MainTabView()
                    // Dil sağdan-sola (Arapça) ile soldan-sağa arasında değişince bütün
                    // ekranı sıfırdan kuruyoruz: aksi halde liste (List) gibi UIKit
                    // tabanlı bileşenler eski yönde "aynalı" kalıyordu.
                    // Tema bu kimliğe dahil DEĞİL: tema değişince ekranı sıfırdan
                    // kurmak açık olan Ayarlar penceresini kapatıyordu.
                    // Metin boyutu değişince yazılar yeni boyutla yeniden çizilir.
                    .id("rtl-\(loc.language.isRightToLeft)-\(String(describing: dynamicTypeSize))")
                    // Çok büyük erişilebilirlik boyutlarında düzen bozulmasın.
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                    .transition(.opacity)
            }

            if showSplash {
                SplashView(isFinished: Binding(
                    get: { !showSplash },
                    set: { finished in
                        guard finished else { return }
                        withAnimation(.easeOut(duration: 0.25)) {
                            showSplash = false
                        }
                    }
                ))
                .transition(.opacity)
            } else if !hasSeenWelcome {
                // İlk kurulumda, herhangi bir izin istemeden önce
                // kullanıcıyı karşılayıp uygulamayı tanıtıyoruz.
                WelcomeOnboardingView {
                    // "Hadi Başlayalım"dan sonra uygulama normal açılır.
                    // Konum izni ana ekran açılınca istenir; bildirim izni
                    // ise konum kararından ~30 saniye sonra (bkz. startPermissionFlow).
                    withAnimation(.easeOut(duration: 0.3)) {
                        hasSeenWelcome = true
                    }
                    trackReviewLaunch()
                    startPermissionFlow()
                }
                .transition(.opacity)
            }
        }
        .preferredColorScheme(isDarkTheme ? .dark : .light)
        .environment(\.layoutDirection, loc.language.isRightToLeft ? .rightToLeft : .leftToRight)
        // Alarm ekranı ayrı bir pencerede açılır (bkz. AlarmWindowPresenter):
        // açık olan Ayarlar gibi pencereler kapanmaz.
        .onChange(of: notificationManager.activeAlarmTitle != nil) { _, _ in
            AlarmWindowPresenter.shared.sync()
        }
        .onChange(of: loc.language.isRightToLeft) { _, rtl in
            Self.applyUIKitDirection(rtl)
        }
        .onAppear {
            // Uygulamayı bir alarm bildirimi açtıysa alarm hemen görünsün.
            Self.applyUIKitDirection(loc.language.isRightToLeft)
            AlarmWindowPresenter.shared.sync()
            #if DEBUG
            // Ekran testleri için: -uiTestAlarm YES → 8 sn sonra alarm ekranı.
            if UserDefaults.standard.bool(forKey: "uiTestAlarm") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                    notificationManager.activeAlarmPrayer = ("Öğle", PrayerTracker.dayKey(Date(), timeZone: .current))
                    notificationManager.activeAlarmBody = "Test"
                    notificationManager.activeAlarmTitle = "Test: Namaz Vakti"
                }
            }
            #endif
            // Widget'lar uygulamanın temasını kullansın.
            PrayerWidgetData.saveDarkTheme(isDarkTheme)

            // Karşılama ekranını daha önce gördüyse izin akışını hemen
            // başlat; ilk kurulumdaysa karşılama ekranındaki "Hadi
            // Başlayalım" butonuna basılınca başlayacak (bkz. yukarısı).
            if hasSeenWelcome {
                trackReviewLaunch()
                startPermissionFlow()
            }
        }
        .onChange(of: isDarkTheme) { _, newValue in
            PrayerWidgetData.saveDarkTheme(newValue)
        }
        .alert(loc.t("primer_title", fallback: "Ezan vakitlerinde haber verelim mi?"), isPresented: $showNotificationPrimer) {
            Button(loc.t("primer_yes", fallback: "Evet, haber ver")) {
                requestNotificationPermission()
            }
            Button(loc.t("primer_later", fallback: "Şimdi değil"), role: .cancel) {
                PermissionPrimer.markDeclined()
            }
        } message: {
            Text(loc.t("primer_body", fallback: "Namaz vakti girince telefonun seni uyarsın. Bir sonraki ekranda \"İzin Ver\"e dokunman yeterli. Bu ayarı sonra Ayarlar > Bildirimler'den değiştirebilirsin."))
        }
    }

    /// İzin sıralaması:
    /// 1) Konum izni ana ekran açılınca istenir (HomeView ve burası aynı
    ///    sistem penceresini tetikler, çift pencere çıkmaz).
    /// 2) Kullanıcı konum konusunda karar verince kısa bir açıklama
    ///    ("Ezan vakitlerinde haber verelim mi?") gösterilir.
    /// 3) "Evet" denirse sistemin bildirim izni penceresi açılır.
    /// Bildirim izni daha önce sorulmuşsa beklemeden hazırlık yapılır.
    private func startPermissionFlow() {
        #if DEBUG
        // Ekran testleri için: -uiTestNoPrompts YES → izin pencereleri açılmaz.
        if UserDefaults.standard.bool(forKey: "uiTestNoPrompts") { return }
        #endif
        NotificationManager.shared.isAuthorizationUndetermined { undetermined in
            guard undetermined else {
                // Reklam izni (AB kullanıcıları için form). Reklamlar ancak
                // bundan sonra yüklenir.
                AdConsentManager.shared.gatherConsent()
                requestNotificationPermission()
                return
            }
            onboardingLocationRequester.request {
                // İlk kurulumda reklam izni formu, konum izni penceresiyle
                // üst üste binmesin diye konum kararından sonra gelir.
                AdConsentManager.shared.gatherConsent()
                // Konum penceresi tamamen kapansın, sonra açıklamayı göster.
                guard PermissionPrimer.shouldShow() else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    showNotificationPrimer = true
                }
            }
        }
    }

    /// Bildirim iznini ister. İlk kez verilirse 5 vaktin namaz alarmını
    /// açar ve hemen planlar. Vermezse hiçbir bildirim gönderilmez.
    private func requestNotificationPermission() {
        NotificationManager.shared.requestAuthorization { granted in
            guard granted else { return }
            if NotificationManager.applyFirstGrantDefaults() {
                NotificationManager.shared.rescheduleFromLastKnownLocation()
            }
        }
    }

    /// Ardışık gün sayımı ve değerlendirme isteği takibi (her açılışta).
    private func trackReviewLaunch() {
        if ReviewManager.trackLaunchAndShouldPrompt() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                // Apple'ın kendi penceresi; gösterip göstermemeye iOS karar verir.
                requestReview()
                ReviewManager.markPrompted()
            }
        }
    }
}

#Preview {
    RootView()
}

extension RootView {
    /// UIKit tabanlı parçalar (liste, gezinme çubuğu, geri oku) SwiftUI'nin yazı
    /// yönü ayarını her zaman almıyor; Arapça'da hepsini sağdan sola zorla.
    static func applyUIKitDirection(_ rtl: Bool) {
        let attr: UISemanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
        UIView.appearance().semanticContentAttribute = attr
        UINavigationBar.appearance().semanticContentAttribute = attr
    }
}
