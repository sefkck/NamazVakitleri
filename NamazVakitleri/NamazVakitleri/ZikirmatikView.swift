import SwiftUI

enum ZikirGoalMode: String, CaseIterable, Identifiable {
    case thirtyThree = "33"
    case ninetyNine = "99"
    case unlimited = "Sınırsız"
    case custom = "Özel"

    var id: String { rawValue }
}

struct ZikirmatikView: View {
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("zikir_goalMode") private var goalModeRaw: String = ZikirGoalMode.thirtyThree.rawValue
    @AppStorage("zikir_customGoal") private var customGoal: Int = 100
    @AppStorage("zikir_count") private var count: Int = 0
    @AppStorage("zikir_completedRounds") private var completedRounds: Int = 0

    @State private var customGoalText: String = ""

    private var goalMode: ZikirGoalMode {
        ZikirGoalMode(rawValue: goalModeRaw) ?? .thirtyThree
    }

    private var currentGoal: Int? {
        switch goalMode {
        case .thirtyThree: return 33
        case .ninetyNine: return 99
        case .unlimited: return nil
        case .custom: return max(customGoal, 1)
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Picker("Hedef", selection: Binding(
                    get: { goalMode },
                    set: { newMode in
                        goalModeRaw = newMode.rawValue
                        count = 0
                    }
                )) {
                    ForEach(ZikirGoalMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 12)

                if goalMode == .custom {
                    HStack {
                        Text("Hedef sayı:")
                            .foregroundColor(AppTheme.textPrimary(colorScheme))
                        TextField("Örn. 250", text: $customGoalText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: customGoalText) { _, newValue in
                                if let value = Int(newValue), value > 0 {
                                    customGoal = value
                                }
                            }
                    }
                    .padding(.horizontal)
                    .onAppear { customGoalText = String(customGoal) }
                }

                Spacer()

                VStack(spacing: 6) {
                    if let goal = currentGoal {
                        Text("\(count) / \(goal)")
                            .font(AppTheme.title(46, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary(colorScheme))
                            .monospacedDigit()
                        Text("Kalan: \(max(goal - count, 0))")
                            .font(AppTheme.body(14))
                            .foregroundStyle(AppTheme.textSecondary(colorScheme))
                    } else {
                        Text("\(count)")
                            .font(AppTheme.title(46, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary(colorScheme))
                            .monospacedDigit()
                        Text("Sınırsız")
                            .font(AppTheme.body(14))
                            .foregroundStyle(AppTheme.textSecondary(colorScheme))
                    }

                    if completedRounds > 0 {
                        Text("Tamamlanan tur: \(completedRounds)")
                            .font(AppTheme.body(12))
                            .foregroundStyle(AppTheme.textTertiary(colorScheme))
                    }
                }

                Spacer()

                Button {
                    increment()
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.accent, AppTheme.accent.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 180, height: 180)
                            .shadow(color: AppTheme.accent.opacity(0.4), radius: 12, y: 6)

                        Text("Çek")
                            .font(AppTheme.title(28, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(ZikirButtonStyle())
                .padding(.vertical, 12)

                Text("Zikir çekmek için düğmeye dokun")
                    .font(AppTheme.body(12))
                    .foregroundStyle(AppTheme.textTertiary(colorScheme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()

                Button(role: .destructive) {
                    reset()
                } label: {
                    Text("Sıfırla")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 24)
            .background(AppTheme.background(colorScheme).ignoresSafeArea())
            .navigationTitle("Zikirmatik")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func increment() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        count += 1
        if let goal = currentGoal, count >= goal {
            completedRounds += 1
            count = 0
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private func reset() {
        count = 0
        completedRounds = 0
    }
}

/// Basılınca hafifçe küçülen sade buton stili.
private struct ZikirButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    ZikirmatikView()
}
