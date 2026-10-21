import SwiftUI
import GoogleMobileAds

/// Google AdMob banner reklamını gösterir. Reklam izni (AdConsentManager)
/// alınmadan hiçbir reklam isteği gönderilmez; o sırada boş alan kalır.
///
/// ⚠️ YAYINA ÇIKMADAN ÖNCE: Aşağıdaki `productionAdUnitID` değerini
/// kendi AdMob hesabından aldığın GERÇEK banner reklam birimi ID'siyle
/// değiştir (admob.google.com > Uygulamalar > Reklam Birimleri).
/// Test ID'siyle yayına çıkarsan hesabın askıya alınabilir.
struct AdBannerView: View {
    /// TODO: Buraya kendi gerçek banner reklam birimi ID'ni yapıştır.
    /// Örnek format: "ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY"
    static let productionAdUnitID = "ca-app-pub-3940256099942544/2435281174"

    var adUnitID: String = AdBannerView.productionAdUnitID
    @ObservedObject private var consent = AdConsentManager.shared

    var body: some View {
        if consent.canRequestAds {
            BannerRepresentable(adUnitID: adUnitID)
        } else {
            Color.clear
        }
    }
}

private struct BannerRepresentable: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = adUnitID
        banner.rootViewController = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}
}
