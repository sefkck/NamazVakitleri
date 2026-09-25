import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isDarkTheme") private var isDarkTheme: Bool = false

    @AppStorage("useManualLocation") private var useManualLocation: Bool = false
    @AppStorage("manualProvinceName") private var manualProvinceName: String = ""
    @AppStorage("manualLatitude") private var manualLatitude: Double = 0
    @AppStorage("manualLongitude") private var manualLongitude: Double = 0
    @AppStorage("ezanNotificationsEnabled") private var ezanNotificationsEnabled: Bool = false

    @State private var showProvincePicker = false
    @State private var showAddressSearch = false
    @State private var showLocationOptions = false

    var body: some View {
        NavigationView {
            Form {
                Section("Genel") {
                    Toggle(isOn: $useManualLocation) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Konum Kullanımı")
                                Text("Kapalıyken GPS, açıkken elle seçtiğin konum kullanılır")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "location.fill")
                                .foregroundColor(AppTheme.accent)
                        }
                    }

                    if useManualLocation {
                        Button {
                            showLocationOptions = true
                        } label: {
                            HStack {
                                Label("Manuel Konum", systemImage: "mappin.and.ellipse")
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(manualProvinceName.isEmpty ? "Seçilmedi" : manualProvinceName)
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .confirmationDialog("Konum seçim yöntemi", isPresented: $showLocationOptions) {
                            Button("Mahalle / Adres Ara") { showAddressSearch = true }
                            Button("İl Merkezinden Seç") { showProvincePicker = true }
                        }
                    }

                    Toggle(isOn: $ezanNotificationsEnabled) {
                        Label("Bildirimler", systemImage: "bell.fill")
                            .foregroundColor(.primary)
                    }
                    .tint(AppTheme.accent)
                    .onChange(of: ezanNotificationsEnabled) { _, newValue in
                        if newValue {
                            NotificationManager.shared.requestPermission()
                        } else {
                            NotificationManager.shared.cancelAll()
                        }
                    }
                }

                Section("Diğer") {
                    HStack {
                        Label("Dil", systemImage: "globe")
                        Spacer()
                        Text("Türkçe").foregroundStyle(.secondary)
                    }
                    NavigationLink {
                        aboutView
                    } label: {
                        Label("Hakkında", systemImage: "info.circle")
                    }
                    NavigationLink {
                        privacyView
                    } label: {
                        Label("Gizlilik Politikası", systemImage: "hand.raised.fill")
                    }
                }

                Section("Reklam") {
                    AdBannerView()
                        .frame(height: 50)
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

    private var aboutView: some View {
        List {
            Text("Namaz Vakitleri, günlük namaz vakitlerini, kıble yönünü, Kur'an-ı Kerim'i ve daha fazlasını tek bir yerde sunan bir uygulamadır.")
            HStack {
                Text("Sürüm")
                Spacer()
                Text("0.1").foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Hakkında")
    }

    private var privacyView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Gizlilik Politikası")
                    .font(.title2.bold())

                Text("Son güncelleme: 25 Eylül 2026")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                privacySection(
                    title: "1. Veri Sorumlusu",
                    body: "Bu uygulama (\"Namaz Vakitleri\"), işbu Gizlilik Politikası kapsamında kişisel verilerinizin 6698 sayılı Kişisel Verilerin Korunması Kanunu (\"KVKK\") ve ilgili mevzuata uygun şekilde işlenmesini taahhüt eder."
                )

                privacySection(
                    title: "2. İşlenen Veriler ve Amaçları",
                    body: "Uygulama, aşağıdaki verileri yalnızca belirtilen amaçlarla işler:\n\n• Konum Bilgisi: Bulunduğunuz yere göre namaz vakitlerinin, kıble yönünün ve yakınınızdaki camilerin hesaplanması amacıyla kullanılır. Cihazınızda saklanır; sunucularımıza aktarılmaz.\n• Bildirim Tercihleri: Ezan vakti bildirimlerini gönderebilmek için cihaz izinleri kullanılır.\n• Kullanım/Reklam Verileri: Uygulama içinde gösterilen reklamlar, Google AdMob altyapısı tarafından sağlanır. Google, reklamların kişiselleştirilmesi amacıyla cihaz tanımlayıcıları gibi verileri kendi gizlilik politikası çerçevesinde işleyebilir."
                )

                privacySection(
                    title: "3. Üçüncü Taraf Hizmet Sağlayıcılar",
                    body: "Reklam gösterimi için Google AdMob hizmetinden faydalanılmaktadır. Google'ın veri işleme uygulamaları hakkında bilgi için Google Gizlilik Politikası'nı inceleyebilirsiniz. Uygulama, konum ve namaz vakti hesaplamaları için genel kullanıma açık coğrafi/astronomik hesaplama kaynaklarından yararlanabilir."
                )

                privacySection(
                    title: "4. Verilerin Saklanması ve Güvenliği",
                    body: "Uygulama herhangi bir kullanıcı hesabı veya kimlik doğrulama sistemi barındırmaz. Konum ve tercih verileriniz yalnızca kendi cihazınızda saklanır. Uygulama tarafından herhangi bir kişisel veri, kimliğinizle ilişkilendirilecek şekilde sunucu tarafında toplanmaz veya üçüncü kişilerle paylaşılmaz."
                )

                privacySection(
                    title: "5. Kullanıcı Hakları",
                    body: "KVKK'nın 11. maddesi uyarınca; kişisel verilerinizin işlenip işlenmediğini öğrenme, işlenmişse buna ilişkin bilgi talep etme, işlenme amacını ve amacına uygun kullanılıp kullanılmadığını öğrenme haklarına sahipsiniz. Konum izninizi ve bildirim izninizi dilediğiniz zaman cihazınızın Ayarlar menüsünden geri alabilirsiniz."
                )

                privacySection(
                    title: "6. Politika Değişiklikleri",
                    body: "İşbu Gizlilik Politikası, yasal düzenlemeler veya uygulama işlevlerindeki değişiklikler doğrultusunda güncellenebilir. Güncel sürüm her zaman bu ekranda yayımlanır."
                )

                privacySection(
                    title: "7. İletişim",
                    body: "Gizlilik uygulamalarımızla ilgili sorularınız için uygulama mağazası üzerinden geliştiriciyle iletişime geçebilirsiniz."
                )
            }
            .padding()
        }
        .navigationTitle("Gizlilik Politikası")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func privacySection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    SettingsView()
}
