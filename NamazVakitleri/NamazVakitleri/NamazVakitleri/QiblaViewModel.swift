import Foundation
import CoreLocation
import Combine

final class QiblaViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var headingDegrees: Double = 0
    @Published var qiblaBearing: Double = 0
    @Published var isReady = false
    @Published var errorMessage: String?

    private let manager = CLLocationManager()
    private let kaabaLatitude = 21.4225
    private let kaabaLongitude = 39.8262

    override init() {
        super.init()
        manager.delegate = self
        manager.headingFilter = 1
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func start(fixedCoordinate: CLLocationCoordinate2D? = nil) {
        guard CLLocationManager.headingAvailable() else {
            errorMessage = "Cihazında pusula sensörü bulunamadı."
            return
        }
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingHeading()

        if let fixedCoordinate {
            qiblaBearing = calculateBearing(from: fixedCoordinate)
            isReady = true
        } else {
            manager.startUpdatingLocation()
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        qiblaBearing = calculateBearing(from: location.coordinate)
        isReady = true
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        headingDegrees = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = error.localizedDescription
    }

    /// İki koordinat arasındaki büyük çember (great-circle) açısını hesaplar.
    private func calculateBearing(from coordinate: CLLocationCoordinate2D) -> Double {
        let lat1 = coordinate.latitude * .pi / 180
        let lon1 = coordinate.longitude * .pi / 180
        let lat2 = kaabaLatitude * .pi / 180
        let lon2 = kaabaLongitude * .pi / 180

        let deltaLon = lon2 - lon1
        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        var bearing = atan2(y, x) * 180 / .pi
        bearing = (bearing + 360).truncatingRemainder(dividingBy: 360)
        return bearing
    }
}
