import Foundation
import Combine
import GoogleMobileAds
import UserMessagingPlatform

/// Reklam izni (GDPR / KVKK) akışı. Google'ın UMP kütüphanesi, kullanıcı
/// Avrupa'daysa (veya izin gerekiyorsa) izin formunu gösterir. Reklam SDK'sı
/// ve banner'lar SADECE izin alındıktan sonra (`canRequestAds`) başlar.
final class AdConsentManager: ObservableObject {
    static let shared = AdConsentManager()

    /// true olunca reklam yüklenebilir. AdBannerView bunu izler.
    @Published private(set) var canRequestAds = false
    /// Kullanıcının izin tercihini sonradan değiştirebileceği form gerekli mi
    /// (Ayarlar'da "Reklam Gizlilik Tercihleri" satırı bununla görünür).
    @Published private(set) var privacyOptionsRequired = false

    private var isGathering = false
    private var adsStarted = false

    private init() {}

    /// Açılışta bir kez çağrılır. Önceki oturumdan izin varsa reklamlar
    /// hemen başlar; yoksa form gösterilir ve sonuca göre başlar.
    func gatherConsent() {
        startAdsIfAllowed()
        guard !isGathering else { return }
        isGathering = true

        ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters()) { [weak self] _ in
            ConsentForm.loadAndPresentIfRequired(from: nil) { _ in
                DispatchQueue.main.async {
                    self?.isGathering = false
                    self?.startAdsIfAllowed()
                }
            }
        }
    }

    /// Ayarlar'dan izin tercihini değiştirme formunu açar.
    func presentPrivacyOptions() {
        ConsentForm.presentPrivacyOptionsForm(from: nil) { [weak self] _ in
            DispatchQueue.main.async { self?.startAdsIfAllowed() }
        }
    }

    private func startAdsIfAllowed() {
        privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        guard ConsentInformation.shared.canRequestAds else { return }
        if !adsStarted {
            adsStarted = true
            Self.applyAdPolicy()
            MobileAds.shared.start(completionHandler: nil)
        }
        canRequestAds = true
    }

    /// Dini uygulama: sadece genel izleyiciye uygun (G) reklamlar ve
    /// kişiselleştirilmemiş reklam (kullanıcıdan reklam için kişisel veri
    /// toplanmaz). Kategori engelleri (alkol, kumar, flört vb.) ayrıca AdMob
    /// hesabında "Engelleme kontrolleri"nden yapılır.
    static func applyAdPolicy() {
        let config = MobileAds.shared.requestConfiguration
        config.maxAdContentRating = .general
        config.publisherPrivacyPersonalizationState = .disabled
    }
}
