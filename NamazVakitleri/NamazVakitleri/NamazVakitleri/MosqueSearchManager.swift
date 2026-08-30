import Foundation
import Combine
import MapKit
import CoreLocation

struct MosqueResult: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let distanceMeters: Double

    var distanceText: String {
        distanceMeters < 1000
            ? String(format: "%.0f m", distanceMeters)
            : String(format: "%.1f km", distanceMeters / 1000)
    }
}

final class MosqueSearchManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var mosques: [MosqueResult] = []
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.9334, longitude: 32.8597),
        latitudinalMeters: 3000,
        longitudinalMeters: 3000
    )
    @Published var isSearching = false
    @Published var errorMessage: String?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
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
        errorMessage = "Konum alınamadı: \(error.localizedDescription)"
    }

    private func search(near location: CLLocation) {
        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "Cami"
        request.region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 5000, longitudinalMeters: 5000)

        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, error in
            guard let self else { return }
            self.isSearching = false
            guard let items = response?.mapItems else {
                self.errorMessage = "Yakında cami bulunamadı."
                return
            }
            self.mosques = items.map { item in
                let itemLocation = CLLocation(latitude: item.placemark.coordinate.latitude, longitude: item.placemark.coordinate.longitude)
                return MosqueResult(
                    name: item.name ?? "Cami",
                    coordinate: item.placemark.coordinate,
                    distanceMeters: location.distance(from: itemLocation)
                )
            }
            .sorted { $0.distanceMeters < $1.distanceMeters }
        }
    }
}
