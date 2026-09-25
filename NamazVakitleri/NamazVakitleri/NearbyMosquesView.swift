import SwiftUI
import MapKit

struct NearbyMosquesView: View {
    @StateObject private var searchManager = MosqueSearchManager()

    @AppStorage("useManualLocation") private var useManualLocation: Bool = false
    @AppStorage("manualLatitude") private var manualLatitude: Double = 0
    @AppStorage("manualLongitude") private var manualLongitude: Double = 0
    @AppStorage("manualProvinceName") private var manualProvinceName: String = ""

    private var manualCoordinate: CLLocationCoordinate2D? {
        guard useManualLocation, !manualProvinceName.isEmpty else { return nil }
        return CLLocationCoordinate2D(latitude: manualLatitude, longitude: manualLongitude)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Map(coordinateRegion: $searchManager.region, showsUserLocation: true, annotationItems: searchManager.mosques) { mosque in
                    MapMarker(coordinate: mosque.coordinate, tint: .red)
                }
                .frame(height: 280)

                if searchManager.isSearching {
                    ProgressView("Yakındaki camiler aranıyor...")
                        .padding()
                } else if let errorMessage = searchManager.errorMessage, searchManager.mosques.isEmpty {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .padding()
                } else {
                    List(searchManager.mosques) { mosque in
                        HStack {
                            Image(systemName: "building.columns.fill")
                                .foregroundColor(AppTheme.accent)
                            VStack(alignment: .leading) {
                                Text(mosque.name)
                                    .font(.body)
                                Text(mosque.distanceText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Yakındaki Camiler")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { searchManager.start(fixedCoordinate: manualCoordinate) }
        }
    }
}

#Preview {
    NearbyMosquesView()
}
