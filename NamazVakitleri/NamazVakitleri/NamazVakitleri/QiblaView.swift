import SwiftUI
import CoreLocation

struct QiblaView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = QiblaViewModel()

    /// Ayarlarda "Elle konum seç" açıksa buraya o koordinat gelir,
    /// kapalıysa nil gelir ve GPS kullanılır.
    var manualCoordinate: CLLocationCoordinate2D? = nil

    private var arrowRotation: Double {
        viewModel.qiblaBearing - viewModel.headingDegrees
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                Spacer()

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                } else if !viewModel.isReady {
                    ProgressView("Konum ve pusula bekleniyor...")
                } else {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                            .frame(width: 260, height: 260)

                        Image(systemName: "location.north.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.orange)
                            .rotationEffect(.degrees(arrowRotation))
                            .animation(.easeInOut(duration: 0.2), value: arrowRotation)
                    }

                    Text("Telefonu düz tutup ok, Kâbe yönünü gösterene kadar çevir.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Text("Kıble açısı: \(Int(viewModel.qiblaBearing))°")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .navigationTitle("Kıble Bul")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { dismiss() }
                }
            }
            .onAppear { viewModel.start(fixedCoordinate: manualCoordinate) }
            .onDisappear { viewModel.stop() }
        }
    }
}

#Preview {
    QiblaView()
}
