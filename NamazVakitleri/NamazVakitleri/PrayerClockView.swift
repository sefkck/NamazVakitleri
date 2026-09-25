import SwiftUI

/// Namaz vakitlerini 24 saatlik bir kadran üzerinde, gerçek saatlerine
/// karşılık gelen açıya yerleştirip dışa doğru çizgiyle çıkan etiketlerle
/// gösteren dairesel gösterge. Ortada sıradaki vakit ve kalan süre yazar.
struct PrayerClockView: View {
    let prayers: [(name: String, date: Date)]
    let nextPrayerName: String
    let remainingTimeText: String
    let timeZone: TimeZone

    private let ringDiameter: CGFloat = 220
    private let calloutRadius: CGFloat = 158

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.28), lineWidth: 1.5)
                    .frame(width: ringDiameter, height: ringDiameter)
                    .position(center)

                ForEach(Array(prayers.enumerated()), id: \.offset) { _, prayer in
                    calloutView(for: prayer, center: center)
                }

                VStack(spacing: 6) {
                    Text("Sıradaki vakit")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.75))
                    Text(nextPrayerName)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Text(remainingTimeText)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                        .monospacedDigit()
                }
                .position(center)
            }
        }
        .frame(width: 340, height: 340)
    }

    @ViewBuilder
    private func calloutView(for prayer: (name: String, date: Date), center: CGPoint) -> some View {
        let angleDeg = angle(for: prayer.date)
        let ringPoint = point(center: center, radius: ringDiameter / 2, angleDegrees: angleDeg)
        let calloutPoint = point(center: center, radius: calloutRadius, angleDegrees: angleDeg)
        let isNext = prayer.name == nextPrayerName

        Path { path in
            path.move(to: ringPoint)
            path.addLine(to: calloutPoint)
        }
        .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        .foregroundColor(.white.opacity(0.45))

        VStack(spacing: 2) {
            Text(prayer.name)
                .font(.caption2)
                .fontWeight(.semibold)
            Text(formattedTime(prayer.date))
                .font(.caption2)
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule().strokeBorder(
                        isNext ? Color.orange.opacity(0.8) : Color.white.opacity(0.4),
                        style: StrokeStyle(lineWidth: 1, dash: [2, 2])
                    )
                )
        )
        .foregroundColor(isNext ? .orange : .white)
        .position(calloutPoint)
    }

    private func angle(for date: Date) -> Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let hour = Double(calendar.component(.hour, from: date))
        let minute = Double(calendar.component(.minute, from: date))
        let fraction = (hour + minute / 60) / 24
        return fraction * 360 - 90 // 00:00 en üstte olsun
    }

    private func point(center: CGPoint, radius: CGFloat, angleDegrees: Double) -> CGPoint {
        let radians = angleDegrees * .pi / 180
        return CGPoint(x: center.x + radius * cos(radians), y: center.y + radius * sin(radians))
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }
}

#Preview {
    ZStack {
        SkyBackgroundView()
        PrayerClockView(
            prayers: [
                ("İmsak", Date()), ("Güneş", Date()), ("Öğle", Date()),
                ("İkindi", Date()), ("Akşam", Date()), ("Yatsı", Date())
            ],
            nextPrayerName: "Öğle",
            remainingTimeText: "02:14:08",
            timeZone: .current
        )
    }
}
