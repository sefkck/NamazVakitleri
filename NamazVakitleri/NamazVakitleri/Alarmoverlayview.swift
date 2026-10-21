import SwiftUI
import AudioToolbox

/// Namaz vakti bildirimi geldiğinde (uygulama ön plandayken) gösterilen
/// tam ekran alarm görünümü. Kapatılana kadar sık aralıklarla ses ve
/// titreşimle "dı dı dı" tarzı ısrarcı bir alarm hissi verir.
///
/// ÖNEMLİ SINIRLAMA: iOS, üçüncü parti uygulamaların kilit ekranında ya
/// da arka plandayken gerçek bir çalar saat gibi tam ekran uyarı
/// vermesine izin vermez - bu sadece Apple'ın çok kısıtlı verdiği
/// "Critical Alerts" iznine sahip uygulamalarda mümkündür. Bu görünüm bu
/// yüzden sadece uygulama açıkken/ön plandayken devreye girer;
/// arka plandayken kullanıcı "time sensitive" (Odak modlarını delen,
/// öncelikli) bir bildirim banner'ı görür.
struct AlarmOverlayView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let message: String
    let onDismiss: () -> Void
    let onSnooze: () -> Void

    @State private var pulse = false
    @State private var soundTimer: Timer?

    var body: some View {
        ZStack {
            AppTheme.background(colorScheme).ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.18))
                        .frame(width: pulse ? 220 : 180, height: pulse ? 220 : 180)
                        .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulse)

                    Image(systemName: "bell.and.waves.left.and.right.fill")
                        .font(.system(size: 64))
                        .foregroundColor(AppTheme.accent)
                }

                VStack(spacing: 10) {
                    Text(title)
                        .font(AppTheme.title(32, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundColor(AppTheme.textPrimary(colorScheme))

                    Text(message)
                        .font(AppTheme.body(16))
                        .multilineTextAlignment(.center)
                        .foregroundColor(AppTheme.textSecondary(colorScheme))
                }
                .padding(.horizontal, 32)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        stopSound()
                        onDismiss()
                    } label: {
                        Text(loc.t("alarm_prayed", fallback: "Kıldım"))
                            .font(AppTheme.body(17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 16))
                    }

                    Button {
                        stopSound()
                        onSnooze()
                    } label: {
                        Text(loc.t("alarm_snooze", fallback: "Birazdan Hatırlat"))
                            .font(AppTheme.body(16, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary(colorScheme))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            pulse = true
            startSound()
        }
        .onDisappear {
            stopSound()
        }
    }

    private func startSound() {
        fireBeat()
        // Kısa aralıklarla tekrar eden ses + titreşim, tek seferlik bir
        // "tın" yerine gerçek bir alarmın ısrarcılığını taklit eder.
        soundTimer = Timer.scheduledTimer(withTimeInterval: 0.9, repeats: true) { _ in
            fireBeat()
        }
    }

    private func fireBeat() {
        guard !DebugMute.isOn else { return }
        AudioServicesPlayAlertSound(SystemSoundID(1005))
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    private func stopSound() {
        soundTimer?.invalidate()
        soundTimer = nil
    }
}
