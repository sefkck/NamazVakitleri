import SwiftUI

/// Reklam entegrasyonu (ör. Google AdMob) için ayrılmış görsel alan.
/// Şimdilik statik bir placeholder; ileride burada gerçek reklam
/// SDK'sının banner/native view'ı gösterilecek.
struct AdPlaceholderView: View {
    var label: String = "Reklam Alanı"
    var height: CGFloat = 60

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
            .foregroundColor(.gray.opacity(0.5))
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay(
                Text(label)
                    .font(.caption)
                    .foregroundColor(.gray)
            )
    }
}

#Preview {
    AdPlaceholderView(label: "Reklam Banner Alanı")
        .padding()
}
