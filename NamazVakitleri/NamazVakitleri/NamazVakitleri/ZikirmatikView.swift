import SwiftUI

enum ZikirGoalMode: String, CaseIterable, Identifiable {
    case thirtyThree = "33"
    case ninetyNine = "99"
    case unlimited = "Sınırsız"
    case custom = "Özel"

    var id: String { rawValue }
}

struct ZikirmatikView: View {
    @Environment(\.dismiss) private var dismiss

    // @AppStorage kullanıldığı için uygulama kapanıp açılsa bile
    // sayaç, hedef ve tur bilgisi kaybolmaz.
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
            VStack(spacing: 28) {

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

                if goalMode == .custom {
                    HStack {
                        Text("Hedef sayı:")
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

                VStack(spacing: 8) {
                    if let goal = currentGoal {
                        Text("\(count) / \(goal)")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("Kalan: \(max(goal - count, 0))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(count)")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("Sınırsız")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if completedRounds > 0 {
                        Text("Tamamlanan tur: \(completedRounds)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    increment()
                } label: {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 180, height: 180)
                        .overlay(
                            Text("Çek")
                                .font(.title)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        )
                }
                .buttonStyle(.plain)

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
            .navigationTitle("Zikirmatik")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }

    private func increment() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
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

#Preview {
    ZikirmatikView()
}

