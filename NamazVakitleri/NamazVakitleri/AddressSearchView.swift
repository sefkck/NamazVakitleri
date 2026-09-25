import SwiftUI
import MapKit

struct AddressSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var completer = AddressSearchCompleter()

    @Binding var manualProvinceName: String
    @Binding var manualLatitude: Double
    @Binding var manualLongitude: Double

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
            .searchable(text: $completer.query, prompt: "Mahalle, semt veya adres yaz")
            .navigationTitle("Adres Ara")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }

    private func select(_ completion: MKLocalSearchCompletion) {
        completer.resolveCoordinate(for: completion) { coordinate, name in
            guard let coordinate else { return }
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
