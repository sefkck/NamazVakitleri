import SwiftUI

struct ProvincePickerView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var manualProvinceName: String
    @Binding var manualLatitude: Double
    @Binding var manualLongitude: Double

    @State private var searchText = ""

    private var filteredProvinces: [TurkishProvince] {
        if searchText.isEmpty { return TurkishProvince.all }
        return TurkishProvince.all.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationView {
            List(filteredProvinces) { province in
                Button {
                    manualProvinceName = province.name
                    manualLatitude = province.latitude
                    manualLongitude = province.longitude
                    dismiss()
                } label: {
                    HStack {
                        Text(province.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        if province.name == manualProvinceName {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "İl ara")
            .navigationTitle("İl Seç")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ProvincePickerView(
        manualProvinceName: .constant("Nevşehir"),
        manualLatitude: .constant(38.6939),
        manualLongitude: .constant(34.6857)
    )
}
