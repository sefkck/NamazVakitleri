import SwiftUI
import CoreLocation

struct QiblaView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = QiblaViewModel()

    @AppStorage("useManualLocation") private var useManualLocation: Bool = false
    @AppStorage("manualLatitude") private var manualLatitude: Double = 0
    @AppStorage("manualLongitude") private var manualLongitude: Double = 0
    @AppStorage("manualProvinceName") private var manualProvinceName: String = ""

    private var manualCoordinate: CLLocationCoordinate2D? {
        guard useManualLocation, !manualProvinceName.isEmpty else { return nil }
        return CLLocationCoordinate2D(latitude: manualLatitude, longitude: manualLongitude)
    }

    private var arrowRotation: Double {
        viewModel.qiblaBearing - viewModel.headingDegrees
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background(colorScheme).ignoresSafeArea()

                VStack(spacing: 32) {
                    Spacer()

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                    } else if !viewModel.isReady {
                        ProgressView("Konum ve pusula bekleniyor...")
                            .tint(AppTheme.accent)
                    } else {
                        VStack(spacing: 4) {
                            Text("Kıble Yönü")
                                .font(AppTheme.body(13))
                                .foregroundStyle(AppTheme.textSecondary(colorScheme))
                            Text("\(Int(viewModel.qiblaBearing))°")
                                .font(AppTheme.title(40, weight: .bold))
                                .foregroundColor(AppTheme.textPrimary(colorScheme))
                        }

                        ZStack {
                            Circle()
                                .fill(AppTheme.cardFill(colorScheme))
                                .frame(width: 260, height: 260)

                            // Derece işaretleri
                            ForEach(0..<24, id: \.self) { i in
                                Rectangle()
                                    .fill(AppTheme.textTertiary(colorScheme))
                                    .frame(width: i % 6 == 0 ? 2.5 : 1, height: i % 6 == 0 ? 12 : 7)
                                    .offset(y: -118)
                                    .rotationEffect(.degrees(Double(i) * 15))
                            }

                            Circle()
                                .stroke(AppTheme.cardStroke(colorScheme), lineWidth: 2)
                                .frame(width: 260, height: 260)

                            // Kâbe - sade, kod ile çizilmiş küp
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.black)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Rectangle()
                                        .fill(AppTheme.gold)
                                        .frame(height: 8)
                                        .offset(y: -6)
                                )
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(.white.opacity(0.15), lineWidth: 1))

                            Image(systemName: "location.north.fill")
                                .font(.system(size: 56))
                                .foregroundColor(AppTheme.accent)
                                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                                .offset(y: -90)
                                .rotationEffect(.degrees(arrowRotation))
                                .animation(.easeInOut(duration: 0.2), value: arrowRotation)
                        }
                        .frame(width: 260, height: 260)

                        Text("Telefonu düz tutup ok, Kâbe yönünü gösterene kadar çevir.")
                            .font(AppTheme.body(13))
                            .foregroundStyle(AppTheme.textSecondary(colorScheme))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Kıble Bul")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { viewModel.start(fixedCoordinate: manualCoordinate) }
            .onDisappear { viewModel.stop() }
        }
    }
}

#Preview {
    QiblaView()
}
