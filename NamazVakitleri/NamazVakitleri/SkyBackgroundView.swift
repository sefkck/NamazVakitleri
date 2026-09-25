import SwiftUI

/// Derin mavi gökyüzü gradyanı üzerinde yavaşça sağa doğru süzülen
/// bulutlarla animasyonlu arka plan.
struct SkyBackgroundView: View {
    @State private var driftPhase: CGFloat = 0

    private let cloudConfigs: [(yFraction: CGFloat, size: CGFloat, speed: Double, opacity: Double, startOffset: CGFloat)] = [
        (0.10, 130, 55, 0.85, 0),
        (0.20, 90, 42, 0.65, 260),
        (0.32, 160, 70, 0.55, 520),
        (0.16, 70, 35, 0.45, 120),
        (0.27, 110, 60, 0.5, 400)
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.04, green: 0.10, blue: 0.32),
                        Color(red: 0.07, green: 0.20, blue: 0.52),
                        Color(red: 0.12, green: 0.34, blue: 0.70)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                ForEach(0..<cloudConfigs.count, id: \.self) { index in
                    let config = cloudConfigs[index]
                    CloudShape()
                        .fill(Color.white.opacity(config.opacity))
                        .frame(width: config.size, height: config.size * 0.5)
                        .blur(radius: 3)
                        .position(
                            x: cloudX(width: geo.size.width, startOffset: config.startOffset),
                            y: geo.size.height * config.yFraction
                        )
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.linear(duration: 60).repeatForever(autoreverses: false)) {
                driftPhase = 2000
            }
        }
    }

    private func cloudX(width: CGFloat, startOffset: CGFloat) -> CGFloat {
        let span = width + 300
        let value = (driftPhase + startOffset).truncatingRemainder(dividingBy: span)
        return value - 150
    }
}

/// Birkaç üst üste binen oval ile basit, yumuşak hatlı bir bulut şekli.
struct CloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.addEllipse(in: CGRect(x: 0, y: h * 0.35, width: w * 0.6, height: h * 0.65))
        path.addEllipse(in: CGRect(x: w * 0.28, y: 0, width: w * 0.55, height: h * 0.85))
        path.addEllipse(in: CGRect(x: w * 0.5, y: h * 0.25, width: w * 0.5, height: h * 0.65))
        return path
    }
}

#Preview {
    SkyBackgroundView()
}
