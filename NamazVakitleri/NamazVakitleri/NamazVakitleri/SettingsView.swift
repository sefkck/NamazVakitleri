import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var userStore: UserStore
    @Environment(\.dismiss) private var dismiss
    @Binding var isDarkTheme: Bool

    @AppStorage("useManualLocation") private var useManualLocation: Bool = false
    @AppStorage("manualProvinceName") private var manualProvinceName: String = ""
    @AppStorage("manualLatitude") private var manualLatitude: Double = 0
    @AppStorage("manualLongitude") private var manualLongitude: Double = 0

    @State private var showProvincePicker = false
    @State private var showAddressSearch = false

    private var isPro: Bool { userStore.currentUser?.isPro == true }

    var body: some View {
        NavigationView {
            Form {
                Section("Görünüm") {
                    Toggle("Koyu tema", isOn: $isDarkTheme)
                }

                Section {
                    Toggle("Elle konum seç", isOn: $useManualLocation)

                    if useManualLocation {
                        HStack {
                            Text("Seçili konum")
                            Spacer()
                            Text(manualProvinceName.isEmpty ? "Seçilmedi" : manualProvinceName)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                        }

                        Button {
                            showAddressSearch = true
                        } label: {
                            HStack {
                                Image(systemName: "mappin.and.ellipse")
                                Text("Mahalle / Adres Ara (daha hassas)")
                            }
                        }

                        Button {
                            showProvincePicker = true
                        } label: {
                            HStack {
                                Image(systemName: "map")
                                Text("İl Merkezinden Seç (hızlı)")
                            }
                        }
                    }
                } header: {
                    Text("Konum")
                } footer: {
                    Text(useManualLocation
                         ? "İl merkezinden seçim namaz vakti ve kıble için yeterlidir, ama 'Yakındaki Camiler' gibi özellikler için genelde şehrin gerçek merkezine uzak sonuçlar verebilir (ör. bir il merkezi koordinatı bazen ıssız bir noktaya denk gelebilir). En doğru sonuç için mahalle/adres aramanı öneririz."
                         : "Kapalıyken uygulama GPS ile bulunduğun konumu otomatik kullanır.")
                }

                if !isPro {
                    Section("Reklam") {
                        AdPlaceholderView(label: "Ayarlar reklam alanı")
                    }
                }
            }
            .navigationTitle("Ayarlar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { dismiss() }
                }
            }
            .sheet(isPresented: $showProvincePicker) {
                ProvincePickerView(
                    manualProvinceName: $manualProvinceName,
                    manualLatitude: $manualLatitude,
                    manualLongitude: $manualLongitude
                )
            }
            .sheet(isPresented: $showAddressSearch) {
                AddressSearchView(
                    manualProvinceName: $manualProvinceName,
                    manualLatitude: $manualLatitude,
                    manualLongitude: $manualLongitude
                )
            }
        }
    }
}

#Preview {
    SettingsView(isDarkTheme: .constant(true)).environmentObject(UserStore())
}
