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
                        Button {
                            showProvincePicker = true
                        } label: {
                            HStack {
                                Text("İl")
                                    .foregroundStyle(Color(.label))
                                Spacer()
                                Text(manualProvinceName.isEmpty ? "Seçilmedi" : manualProvinceName)
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                } header: {
                    Text("Konum")
                } footer: {
                    Text(useManualLocation
                         ? "Namaz vakitleri seçtiğin ilin merkezine göre hesaplanır, GPS kullanılmaz."
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
        }
    }
}

#Preview {
    SettingsView(isDarkTheme: .constant(true)).environmentObject(UserStore())
}
