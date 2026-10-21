import Foundation
import Combine
import MapKit
import CoreLocation

struct MosqueResult: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let distanceMeters: Double
    /// Haritalar'da yol tarifi açmak için.
    let mapItem: MKMapItem

    func openDirections() {
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }

    var distanceText: String {
        DisplayFormat.distance(meters: distanceMeters)
    }
}

final class MosqueSearchManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var mosques: [MosqueResult] = []
    @Published var region: MKCoordinateRegion
    @Published var isSearching = false
    @Published var errorMessage: String?

    private let manager = CLLocationManager()

    override init() {
        // Ana Sayfa'nın daha önce çözdüğü son bilinen konum varsa ekran ilk
        // açıldığında ondan başlar; Ankara sadece hiç konum bilinmiyorsa
        // (uygulama ilk kez açılıyorsa) geçici bir başlangıç noktası olur.
        let cachedLat = UserDefaults.standard.double(forKey: "lastKnownLatitude")
        let cachedLon = UserDefaults.standard.double(forKey: "lastKnownLongitude")
        let initialCenter: CLLocationCoordinate2D
        if cachedLat != 0 || cachedLon != 0 {
            initialCenter = CLLocationCoordinate2D(latitude: cachedLat, longitude: cachedLon)
        } else {
            initialCenter = CLLocationCoordinate2D(latitude: 39.9334, longitude: 32.8597)
        }
        region = MKCoordinateRegion(center: initialCenter, latitudinalMeters: 3000, longitudinalMeters: 3000)

        super.init()
        manager.delegate = self

        if cachedLat != 0 || cachedLon != 0 {
            search(near: CLLocation(latitude: cachedLat, longitude: cachedLon))
        }
    }

    func start(fixedCoordinate: CLLocationCoordinate2D? = nil) {
        if let fixedCoordinate {
            let location = CLLocation(latitude: fixedCoordinate.latitude, longitude: fixedCoordinate.longitude)
            region = MKCoordinateRegion(center: fixedCoordinate, latitudinalMeters: 3000, longitudinalMeters: 3000)
            search(near: location)
        } else {
            manager.requestWhenInUseAuthorization()
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 3000, longitudinalMeters: 3000)
        search(near: location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Son bilinen konumla zaten sonuç gösteriliyorsa hatayı öne çıkarma.
        guard mosques.isEmpty else { return }
        errorMessage = LocalizationManager.shared.tf("mosque_err_location", "Konum alınamadı: %@", error.localizedDescription)
    }

    /// Bu mesafeden uzak sonuçlar "yakındaki cami" sayılmaz. Apple'ın
    /// araması bazen başka bir ülkedeki sonucu da döndürüyordu (Berlin'de
    /// 1770 km uzaktaki bir cami gibi).
    static let maxDistanceMeters: Double = 15_000

    /// Uygulama dili ne olursa olsun, yerel ada göre de bulunsun diye
    /// birden çok arama kelimesi kullanılır.
    private static var queries: [String] {
        let localized = LocalizationManager.shared.t("mosque_query", fallback: "Cami")
        var list = [localized, "mosque", "Cami", "Moschee", "مسجد"]
        var seen = Set<String>()
        list = list.filter { seen.insert($0.lowercased()).inserted }
        return list
    }

    /// Apple Haritalar'da "cami" diye ayrı bir yer türü yok; "Moschee" araması
    /// Berlin'de iç çamaşırı mağazaları bile döndürüyordu. Bu yüzden sadece adında
    /// cami anlamına gelen bir kelime geçen ve mağaza/restoran olmayan yerler kalır.
    static let mosqueKeywords = ["cami", "mescid", "mescit", "mosque", "moschee", "masjid", "mesjid",
                                 "mosquee", "moskee", "islam", "ditib", "diyanet", "مسجد", "جامع"]
    static let excludedCategories: Set<MKPointOfInterestCategory> = [
        .store, .restaurant, .cafe, .bakery, .foodMarket, .nightlife, .brewery, .winery, .hotel, .fitnessCenter, .gasStation
    ]

    static func isMosque(name: String?, category: MKPointOfInterestCategory?) -> Bool {
        if let category, excludedCategories.contains(category) { return false }
        guard let name else { return false }
        let folded = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "tr_TR"))
            .replacingOccurrences(of: "ı", with: "i")
        return mosqueKeywords.contains { folded.contains($0) }
    }

    private func search(near location: CLLocation) {
        isSearching = true
        errorMessage = nil
        let region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 8000, longitudinalMeters: 8000)
        let group = DispatchGroup()
        var items: [MKMapItem] = []
        var anySucceeded = false

        for query in Self.queries {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.region = region
            request.resultTypes = .pointOfInterest
            group.enter()
            MKLocalSearch(request: request).start { response, error in
                if let response {
                    anySucceeded = true
                    items += response.mapItems
                } else if let error = error as? MKError, error.code == .placemarkNotFound {
                    anySucceeded = true
                }
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.isSearching = false
            guard anySucceeded else {
                // Ağ yok / arama servisi hata verdi: "cami yok" demek yanlış olur.
                if self.mosques.isEmpty {
                    self.errorMessage = LocalizationManager.shared.t("mosque_err_search", fallback: "Camiler aranamadı. İnternet bağlantını kontrol edip tekrar dene.")
                }
                return
            }
            var seen = Set<String>()
            self.mosques = items.compactMap { item -> MosqueResult? in
                let coordinate = item.location.coordinate
                let itemLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                let distance = location.distance(from: itemLocation)
                guard distance <= Self.maxDistanceMeters else { return nil }
                guard Self.isMosque(name: item.name, category: item.pointOfInterestCategory) else { return nil }
                // Aynı cami birden çok aramada dönerse bir kez göster.
                let key = String(format: "%.4f,%.4f", coordinate.latitude, coordinate.longitude)
                guard seen.insert(key).inserted else { return nil }
                return MosqueResult(
                    name: item.name ?? LocalizationManager.shared.t("mosque_default", fallback: "Cami"),
                    coordinate: coordinate,
                    distanceMeters: distance,
                    mapItem: item
                )
            }
            .sorted { $0.distanceMeters < $1.distanceMeters }
            if self.mosques.isEmpty {
                self.errorMessage = LocalizationManager.shared.t("mosque_none", fallback: "Yakında cami bulunamadı.")
            }
        }
    }
}
