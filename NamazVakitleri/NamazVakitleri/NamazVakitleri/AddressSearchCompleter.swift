import Foundation
import MapKit
import Combine

final class AddressSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []
    @Published var query: String = "" {
        didSet { completer.queryFragment = query }
    }

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        // Sonuçları Türkiye civarına yakınlaştırmak için kaba bir bölge veriyoruz.
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 39.0, longitude: 35.0),
            latitudinalMeters: 1_500_000,
            longitudinalMeters: 1_500_000
        )
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        results = []
    }

    func resolveCoordinate(for completion: MKLocalSearchCompletion, onResult: @escaping (CLLocationCoordinate2D?, String) -> Void) {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        search.start { response, _ in
            let coordinate = response?.mapItems.first?.placemark.coordinate
            let name = [completion.title, completion.subtitle].filter { !$0.isEmpty }.joined(separator: ", ")
            onResult(coordinate, name.isEmpty ? completion.title : name)
        }
    }
}
