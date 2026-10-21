import SwiftUI

/// Uygulama açılışında ~2.5 saniye gösterilen giriş ekranı.
/// "Safa" yukarıdan, "Kur'an, Namaz, Kıble" aşağıdan gelip ortada
/// birleşir, kısa bir süre durur, sonra yumuşakça açılıp ana menüyü
/// gösterir. "Kiano" adında bir sistem fontu iOS'ta bulunmuyor; en
/// yakın duran zarif imza tarzı sistem fontu olan Snell Roundhand
/// kullanıldı. Gerçek "Kiano" font dosyası (.ttf/.otf) eklenirse
/// buradaki .custom() çağrıları onun adıyla değiştirilebilir.
struct SplashView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var loc = LocalizationManager.shared
    @Binding var isFinished: Bool

    @State private var topOffset: CGFloat = -260
    @State private var bottomOffset: CGFloat = 260
    @State private var textOpacity: Double = 0
    @State private var iconOpacity: Double = 0
    @State private var iconScale: CGFloat = 0.7
    @State private var splashOpacity: Double = 1
    @State private var splashScale: CGFloat = 1

    var body: some View {
        ZStack {
            AppTheme.background(colorScheme).ignoresSafeArea()

            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [AppTheme.gold.opacity(0.3), .clear],
                                center: .center,
                                startRadius: 2,
                                endRadius: 38
                            )
                        )
                        .frame(width: 76, height: 76)

                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(AppTheme.accent)
                }
                .opacity(iconOpacity)
                .scaleEffect(iconScale)
                .padding(.bottom, 6)

                Text("Safa")
                    .font(.custom("SnellRoundhand-Black", size: 52))
                    .foregroundColor(AppTheme.textPrimary(colorScheme))
                    .offset(y: topOffset)
                    .opacity(textOpacity)

                Text(loc.t("splash_subtitle"))
                    .font(.custom("SnellRoundhand", size: 26))
                    .foregroundColor(AppTheme.accent)
                    .offset(y: bottomOffset)
                    .opacity(textOpacity)
            }
        }
        .opacity(splashOpacity)
        .scaleEffect(splashScale)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                topOffset = 0
                bottomOffset = 0
                textOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                iconOpacity = 1
                iconScale = 1
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeIn(duration: 0.4)) {
                    splashOpacity = 0
                    splashScale = 1.06
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                isFinished = true
            }
        }
    }
}

#Preview {
    SplashView(isFinished: .constant(false))
}
