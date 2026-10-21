import SwiftUI
import UIKit
import CoreLocation

struct QiblaView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = QiblaViewModel()

    @AppStorage("useManualLocation") private var useManualLocation: Bool = false
    @AppStorage("manualLatitude") private var manualLatitude: Double = 0
    @AppStorage("manualLongitude") private var manualLongitude: Double = 0
    @AppStorage("manualProvinceName") private var manualProvinceName: String = ""

    /// Ok, Kâbe yönüne kilitlendiğinde tekrar tekrar titreşmemesi için;
    /// sadece "hizalanmadı -> hizalandı" geçişinde bir kez tetiklenir.
    @State private var isAlignedWithQibla = false
    @State private var showMap = false

    private var manualCoordinate: CLLocationCoordinate2D? {
        guard useManualLocation, !manualProvinceName.isEmpty else { return nil }
        return CLLocationCoordinate2D(latitude: manualLatitude, longitude: manualLongitude)
    }

    private var arrowRotation: Double {
        viewModel.arrowAngle
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
            // Pusula ekran boyuna göre küçülür (iPhone SE'de yazılar kesilmesin).
            let dial = min(260, max(180, geo.size.height * 0.42))
            let compact = geo.size.height < 620
            ZStack {
                AppTheme.background(colorScheme).ignoresSafeArea()

                VStack(spacing: compact ? 16 : 32) {
                    Spacer()

                    if !viewModel.isReady, let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                    } else if !viewModel.isReady {
                        ProgressView(loc.t("qibla_waiting", fallback: "Konum ve pusula bekleniyor..."))
                            .tint(AppTheme.accent)
                    } else {
                        VStack(spacing: 4) {
                            Text(loc.t("qibla_direction", fallback: "Kıble Yönü"))
                                .font(AppTheme.body(13))
                                .foregroundStyle(AppTheme.textSecondary(colorScheme))
                            Text("\(Int(viewModel.qiblaBearing.rounded()))°")
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
                                .stroke(
                                    isAlignedWithQibla ? Color.green : AppTheme.cardStroke(colorScheme),
                                    lineWidth: isAlignedWithQibla ? 4 : 2
                                )
                                .frame(width: 260, height: 260)
                                .shadow(color: isAlignedWithQibla ? .green : .clear, radius: isAlignedWithQibla ? 22 : 0)
                                .animation(.easeInOut(duration: 0.25), value: isAlignedWithQibla)

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
                                .foregroundColor(isAlignedWithQibla ? .green : AppTheme.accent)
                                .shadow(
                                    color: isAlignedWithQibla ? .green : .black.opacity(0.25),
                                    radius: isAlignedWithQibla ? 18 : 4,
                                    y: isAlignedWithQibla ? 0 : 2
                                )
                                .offset(y: -90)
                                .rotationEffect(.degrees(arrowRotation))
                                .animation(.easeInOut(duration: 0.2), value: arrowRotation)
                                .animation(.easeInOut(duration: 0.25), value: isAlignedWithQibla)
                        }
                        .frame(width: 260, height: 260)
                        .scaleEffect(dial / 260)
                        .frame(width: dial, height: dial)
                        // Pusula gerçek yönleri gösterir: Arapça (sağdan sola) arayüzde
                        // aynalanırsa ok ters yönü (278° yerine 82°) gösteriyordu.
                        .environment(\.layoutDirection, .leftToRight)

                        if !viewModel.compassUnavailable {
                            Text(loc.t("qibla_hint", fallback: "Telefonu düz tutup ok, Kâbe yönünü gösterene kadar çevir."))
                                .font(AppTheme.body(13))
                                .foregroundStyle(AppTheme.textSecondary(colorScheme))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 32)
                        }

                        if viewModel.compassUnavailable {
                            Text(loc.tf("qibla_no_compass_hint", "Bu cihazda pusula yok, ok dönmez. Kıble, kuzeyden saat yönünde %d°. Telefonun üst kenarını kuzeye çevirince ok kıbleyi gösterir.", Int(viewModel.qiblaBearing.rounded())))
                                .font(AppTheme.body(12))
                                .foregroundStyle(.orange)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 32)
                        }

                        if viewModel.needsCalibration {
                            Text(loc.t("qibla_calibrate", fallback: "Pusula hassasiyeti düşük. Telefonu havada 8 çizerek kalibre et."))
                                .font(AppTheme.body(12))
                                .foregroundStyle(.orange)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 32)
                        }

                        if let info = viewModel.infoMessage {
                            Text(info)
                                .font(AppTheme.body(12))
                                .foregroundStyle(AppTheme.textTertiary(colorScheme))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 32)
                        }
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
            }
            .navigationTitle(loc.t("tab_qibla", fallback: "Kıble Bul"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.userCoordinate != nil {
                        Button { showMap = true } label: {
                            Label(loc.t("qibla_map_button", fallback: "Harita"), systemImage: "map")
                        }
                        .tint(AppTheme.accent)
                    }
                }
            }
            .sheet(isPresented: $showMap) {
                if let origin = viewModel.userCoordinate {
                    QiblaMapView(origin: origin, bearing: viewModel.qiblaBearing)
                }
            }
            #if DEBUG
            // Ekran testi: -uiTab qibla -uiQiblaMap YES
            .onChange(of: viewModel.userCoordinate != nil) { _, ready in
                if ready && UserDefaults.standard.bool(forKey: "uiQiblaMap") { showMap = true }
            }
            #endif
            .onAppear { viewModel.start(fixedCoordinate: manualCoordinate) }
            .onDisappear { viewModel.stop() }
            .onChange(of: arrowRotation) { _, newValue in
                checkQiblaAlignment(newValue)
            }
        }
    }

    /// Ok yukarı (Kâbe yönüne) yaklaştığında, sadece hizalanma anında
    /// bir kez hafif titreşim verir; hizalı kaldığı sürece tekrar
    /// tekrar titremez.
    private func checkQiblaAlignment(_ rotation: Double) {
        let normalized = ((rotation.truncatingRemainder(dividingBy: 360)) + 360)
            .truncatingRemainder(dividingBy: 360)
        let distanceFromZero = min(normalized, 360 - normalized)
        let nowAligned = distanceFromZero <= 3

        if nowAligned && !isAlignedWithQibla {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        isAlignedWithQibla = nowAligned
    }
}

#Preview {
    QiblaView()
}
