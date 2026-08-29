import SwiftUI

struct ProPaymentView: View {
    @EnvironmentObject private var userStore: UserStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "star.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.orange)

                Text("Pro Hesaba Geç")
                    .font(.title2)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 12) {
                    featureRow("Reklamsız deneyim")
                    featureRow("Namaz duaları içeriğine tam erişim")
                    featureRow("Kuran-ı Kerim bölümüne tam erişim")
                }
                .padding(.horizontal, 32)

                Text("₺29,99 / ay")
                    .font(.title3)
                    .fontWeight(.bold)

                Text("Bu bir test ekranıdır, gerçek bir ödeme alınmaz.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    userStore.setProStatus(true)
                    dismiss()
                } label: {
                    Text("Öde ve Pro Ol (Test)")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .navigationTitle("Pro Hesap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func featureRow(_ text: String) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(text)
        }
    }
}

#Preview {
    ProPaymentView().environmentObject(UserStore())
}
