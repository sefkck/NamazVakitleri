import SwiftUI
import MapKit

struct NearbyMosquesView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss
    @StateObject private var searchManager = MosqueSearchManager()

    @AppStorage("useManualLocation") private var useManualLocation: Bool = false
    @AppStorage("manualLatitude") private var manualLatitude: Double = 0
    @AppStorage("manualLongitude") private var manualLongitude: Double = 0
    @AppStorage("manualProvinceName") private var manualProvinceName: String = ""
    @State private var mapPosition: MapCameraPosition = .automatic

    private var manualCoordinate: CLLocationCoordinate2D? {
        guard useManualLocation, !manualProvinceName.isEmpty else { return nil }
        return CLLocationCoordinate2D(latitude: manualLatitude, longitude: manualLongitude)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Map(position: $mapPosition) {
                    UserAnnotation()
                    ForEach(searchManager.mosques) { mosque in
                        Marker(mosque.name, coordinate: mosque.coordinate)
                            .tint(.red)
                    }
                }
                .onReceive(searchManager.$region) { region in
                    mapPosition = .region(region)
                }
                .frame(height: 280)

                if searchManager.isSearching {
                    ProgressView(loc.t("mosque_searching", fallback: "Yakındaki camiler aranıyor..."))
                        .padding()
                } else if let errorMessage = searchManager.errorMessage, searchManager.mosques.isEmpty {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .padding()
                } else {
                    List(searchManager.mosques) { mosque in
                        // Dokununca Haritalar'da yürüyerek yol tarifi açılır.
                        Button {
                            mosque.openDirections()
                        } label: {
                            HStack {
                                Image(systemName: "building.columns.fill")
                                    .foregroundColor(AppTheme.accent)
                                VStack(alignment: .leading) {
                                    Text(mosque.name)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    Text(mosque.distanceText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Label(loc.t("mosque_directions", fallback: "Yol tarifi"), systemImage: "arrow.triangle.turn.up.right.circle.fill")
                                    .labelStyle(.iconOnly)
                                    .font(.title3)
                                    .foregroundColor(AppTheme.accent)
                            }
                        }
                        .accessibilityHint(loc.t("mosque_directions", fallback: "Yol tarifi"))
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(loc.t("more_mosques", fallback: "Yakındaki Camiler"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel(loc.t("common_close", fallback: "Kapat"))
                }
            }
            .onAppear { searchManager.start(fixedCoordinate: manualCoordinate) }
        }
    }
}

#Preview {
    NearbyMosquesView()
}
