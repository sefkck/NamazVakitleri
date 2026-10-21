import SwiftUI
import MapKit

struct AddressSearchView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss
    @StateObject private var completer = AddressSearchCompleter()

    @Binding var manualProvinceName: String
    @Binding var manualLatitude: Double
    @Binding var manualLongitude: Double
    @AppStorage("manualTimeZoneID") private var manualTimeZoneID: String = "Europe/Istanbul"

    var body: some View {
        NavigationView {
            List(Array(completer.results.enumerated()), id: \.offset) { _, result in
                Button {
                    select(result)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.title)
                            .foregroundStyle(.primary)
                        if !result.subtitle.isEmpty {
                            Text(result.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .searchable(text: $completer.query, prompt: loc.t("addr_prompt", fallback: "Mahalle, semt veya adres yaz"))
            .navigationTitle(loc.t("addr_title", fallback: "Adres Ara"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(loc.t("common_close", fallback: "Kapat")) { dismiss() }
                }
            }
        }
    }

    private func select(_ completion: MKLocalSearchCompletion) {
        completer.resolveCoordinate(for: completion) { coordinate, name, timeZone in
            guard let coordinate else { return }
            // Saat dilimi önce yazılır ki enlem/boylam değişince ana ekran doğru saati kullansın.
            manualTimeZoneID = timeZone?.identifier ?? "Europe/Istanbul"
            manualProvinceName = name
            manualLatitude = coordinate.latitude
            manualLongitude = coordinate.longitude
            dismiss()
        }
    }
}

#Preview {
    AddressSearchView(
        manualProvinceName: .constant(""),
        manualLatitude: .constant(0),
        manualLongitude: .constant(0)
    )
}
