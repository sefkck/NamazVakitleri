import SwiftUI

struct ProvincePickerView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss

    @Binding var manualProvinceName: String
    @Binding var manualLatitude: Double
    @Binding var manualLongitude: Double
    @AppStorage("manualTimeZoneID") private var manualTimeZoneID: String = "Europe/Istanbul"

    @State private var searchText = ""

    private var filteredProvinces: [TurkishProvince] {
        if searchText.isEmpty { return TurkishProvince.all }
        return TurkishProvince.all.filter { $0.name.matchesSearch(searchText) }
    }

    var body: some View {
        NavigationView {
            List(filteredProvinces) { province in
                Button {
                    manualTimeZoneID = "Europe/Istanbul"
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
            .searchable(text: $searchText, prompt: loc.t("province_prompt", fallback: "İl ara"))
            .navigationTitle(loc.t("province_title", fallback: "İl Seç"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(loc.t("common_close", fallback: "Kapat")) { dismiss() }
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
