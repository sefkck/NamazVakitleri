import SwiftUI
import MapKit

struct NearbyMosquesView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var searchManager = MosqueSearchManager()

    /// Ayarlarda "Elle konum seç" açıksa buraya o koordinat gelir,
    /// kapalıysa nil gelir ve GPS kullanılır.
    var manualCoordinate: CLLocationCoordinate2D? = nil

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Map(coordinateRegion: $searchManager.region, showsUserLocation: true, annotationItems: searchManager.mosques) { mosque in
                    MapMarker(coordinate: mosque.coordinate, tint: .orange)
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
                                .foregroundColor(.orange)
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
                }
            }
            .navigationTitle("Yakındaki Camiler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { dismiss() }
                }
            }
            .onAppear { searchManager.start(fixedCoordinate: manualCoordinate) }
        }
    }
}

#Preview {
    NearbyMosquesView()
}
