import SwiftUI

enum ZikirGoalMode: String, CaseIterable, Identifiable {
    case thirtyThree = "33"
    case ninetyNine = "99"
    case tesbihat = "Tesbihat"
    case unlimited = "Sınırsız"
    case custom = "Özel"

    var id: String { rawValue }
}

/// Namaz sonrası tesbihat: 33 Sübhanallah, 33 Elhamdülillah, 34 Allahu Ekber
/// (toplam 100). Sayaç 0...99 arası tek sayı; hangi kelimede olunduğu buradan çıkar.
enum Tesbihat {
    static let phases: [(turkish: String, key: String, arabic: String, target: Int)] = [
        ("Sübhanallah", "tesbih_subhanallah", "سُبْحَانَ اللّٰهِ", 33),
        ("Elhamdülillah", "tesbih_elhamdulillah", "اَلْحَمْدُ لِلّٰهِ", 33),
        ("Allahu Ekber", "tesbih_allahuekber", "اَللّٰهُ أَكْبَرُ", 34)
    ]
    static let total = 100

    /// Toplam sayıdan: kaçıncı kelime (0...2), o kelimede kaç kez çekildi.
    static func phase(for count: Int) -> (index: Int, done: Int, target: Int) {
        var remaining = max(0, count)
        for (i, p) in phases.enumerated() {
            if remaining < p.target { return (i, remaining, p.target) }
            remaining -= p.target
        }
        return (phases.count - 1, phases.last!.target, phases.last!.target)
    }
}

struct ZikirmatikView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("zikir_goalMode") private var goalModeRaw: String = ZikirGoalMode.thirtyThree.rawValue
    @AppStorage("zikir_customGoal") private var customGoal: Int = 100
    // Tamamlanan turlar da her hedef modu için ayrı tutulur; bir modu
    // sıfırlamak diğer modların turlarını silmez. (Eski ortak sayaç
    // "zikir_completedRounds" 33'lük moda aktarılır.)
    @AppStorage("zikir_completedRounds") private var completedRounds33: Int = 0
    @AppStorage("zikir_rounds_99") private var completedRounds99: Int = 0
    @AppStorage("zikir_rounds_custom") private var completedRoundsCustom: Int = 0
    @AppStorage("zikir_rounds_tesbihat") private var completedRoundsTesbihat: Int = 0

    // Her hedef modunun kendi sayacı var - modlar arası geçiş yapınca
    // (ör. Sınırsız'dan Özel'e bakıp geri dönünce) hiçbirinin sayısı
    // kaybolmuyor.
    @AppStorage("zikir_count_33") private var count33: Int = 0
    @AppStorage("zikir_count_99") private var count99: Int = 0
    @AppStorage("zikir_count_unlimited") private var countUnlimited: Int = 0
    @AppStorage("zikir_count_custom") private var countCustom: Int = 0
    @AppStorage("zikir_count_tesbihat") private var countTesbihat: Int = 0

    @State private var customGoalText: String = ""
    /// Yanlışlıkla dokunup sayıyı kaybetmemek için "Sıfırla" önce sorar.
    @State private var showResetConfirm = false
    @FocusState private var isCustomFieldFocused: Bool

    private var goalMode: ZikirGoalMode {
        ZikirGoalMode(rawValue: goalModeRaw) ?? .thirtyThree
    }

    private var count: Int {
        get {
            switch goalMode {
            case .thirtyThree: return count33
            case .ninetyNine: return count99
            case .unlimited: return countUnlimited
            case .custom: return countCustom
            case .tesbihat: return countTesbihat
            }
        }
        nonmutating set {
            switch goalMode {
            case .thirtyThree: count33 = newValue
            case .ninetyNine: count99 = newValue
            case .unlimited: countUnlimited = newValue
            case .custom: countCustom = newValue
            case .tesbihat: countTesbihat = newValue
            }
        }
    }

    private var completedRounds: Int {
        get {
            switch goalMode {
            case .thirtyThree: return completedRounds33
            case .ninetyNine: return completedRounds99
            case .unlimited: return 0
            case .custom: return completedRoundsCustom
            case .tesbihat: return completedRoundsTesbihat
            }
        }
        nonmutating set {
            switch goalMode {
            case .thirtyThree: completedRounds33 = newValue
            case .ninetyNine: completedRounds99 = newValue
            case .unlimited: break
            case .custom: completedRoundsCustom = newValue
            case .tesbihat: completedRoundsTesbihat = newValue
            }
        }
    }

    private var currentGoal: Int? {
        switch goalMode {
        case .thirtyThree: return 33
        case .ninetyNine: return 99
        case .unlimited: return nil
        case .custom: return max(customGoal, 1)
        case .tesbihat: return Tesbihat.total
        }
    }

    var body: some View {
        NavigationView {
            // Kısa ekranlarda (iPhone SE gibi) her şey sekme çubuğunun üstünde kalsın.
            GeometryReader { geo in
            let compact = geo.size.height < 620
            ScrollView {
                VStack(spacing: compact ? 14 : 24) {
                Picker(loc.t("zikir_goal", fallback: "Hedef"), selection: Binding(
                    get: { goalMode },
                    set: { newMode in
                        goalModeRaw = newMode.rawValue
                        // Not: artık sayaç sıfırlanmıyor - her modun kendi
                        // sayacı ayrı saklanıyor.
                    }
                )) {
                    ForEach(ZikirGoalMode.allCases) { mode in
                        Text(loc.x(mode.rawValue)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 12)

                if goalMode == .custom {
                    HStack(spacing: 10) {
                        Text(loc.t("zikir_goal_label", fallback: "Hedef sayı:"))
                            .foregroundColor(AppTheme.textSecondary(colorScheme))
                        TextField(loc.t("zikir_placeholder", fallback: "Örn. 250"), text: $customGoalText)
                            .keyboardType(.numberPad)
                            .font(AppTheme.title(18, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary(colorScheme))
                            .monospacedDigit()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.accentSoft(colorScheme)))
                            .frame(maxWidth: 140)
                            .focused($isCustomFieldFocused)
                            .onChange(of: customGoalText) { _, newValue in
                                if let value = Int(newValue), value > 0 {
                                    customGoal = value
                                }
                            }
                        Spacer(minLength: 0)
                        if isCustomFieldFocused {
                            Button(loc.t("common_done", fallback: "Bitti")) { isCustomFieldFocused = false }
                                .font(AppTheme.body(15, weight: .semibold))
                                .foregroundColor(AppTheme.accent)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 14).fill(AppTheme.cardFill(colorScheme)))
                    .padding(.horizontal)
                    .onAppear { customGoalText = String(customGoal) }
                    // "0" ya da boş bırakılırsa kutu gerçek hedefi gösterir (hedef en az 1).
                    .onChange(of: isCustomFieldFocused) { _, focused in
                        if !focused { customGoalText = String(max(customGoal, 1)) }
                    }
                }

                // Boşluğun bir kısmı sayaçtan önce: sayaç ortaya yaklaşır.
                Spacer(minLength: 0)

                VStack(spacing: 6) {
                    if goalMode == .tesbihat {
                        let phase = Tesbihat.phase(for: count)
                        let item = Tesbihat.phases[phase.index]
                        Text(loc.t(item.key, fallback: item.turkish))
                            .font(AppTheme.title(28, weight: .bold))
                            .foregroundColor(AppTheme.accent)
                        Text(item.arabic)
                            .font(.system(size: 22))
                            .foregroundColor(AppTheme.textSecondary(colorScheme))
                        Text("\(phase.done) / \(phase.target)")
                            .font(AppTheme.title(compact ? 38 : 46, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary(colorScheme))
                            .monospacedDigit()
                        // 3 adımın hangisinde olunduğunu gösteren noktalar.
                        HStack(spacing: 6) {
                            ForEach(0..<Tesbihat.phases.count, id: \.self) { i in
                                Capsule()
                                    .fill(i <= phase.index ? AppTheme.accent : AppTheme.cardStroke(colorScheme))
                                    .frame(width: i == phase.index ? 22 : 10, height: 6)
                            }
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(loc.tf("tesbih_step", "%d. adım / 3", phase.index + 1))
                    } else if let goal = currentGoal {
                        Text("\(count) / \(goal)")
                            .font(AppTheme.title(46, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary(colorScheme))
                            .monospacedDigit()
                        Text(loc.tf("zikir_remaining", "Kalan: %d", max(goal - count, 0)))
                            .font(AppTheme.body(14))
                            .foregroundStyle(AppTheme.textSecondary(colorScheme))
                    } else {
                        Text("\(count)")
                            .font(AppTheme.title(46, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary(colorScheme))
                            .monospacedDigit()
                        Text(loc.t("zikir_unlimited", fallback: "Sınırsız"))
                            .font(AppTheme.body(14))
                            .foregroundStyle(AppTheme.textSecondary(colorScheme))
                    }

                    if completedRounds > 0 {
                        Text(loc.tf("zikir_rounds", "Tamamlanan tur: %d", completedRounds))
                            .font(AppTheme.body(12))
                            .foregroundStyle(AppTheme.textTertiary(colorScheme))
                    }

                    Button(role: .destructive) {
                        // Sıfırlanacak bir şey yoksa sormadan geç.
                        if count > 0 || completedRounds > 0 {
                            showResetConfirm = true
                        }
                    } label: {
                        Text(loc.t("zikir_reset", fallback: "Sıfırla"))
                            .font(AppTheme.body(13, weight: .medium))
                    }
                    .padding(.top, 4)
                }
                .padding(.top, compact ? 4 : 12)

                // Sayaç ve "Çek" düğmesi tek grup: aralarında sabit, makul bir boşluk.
                Color.clear.frame(height: compact ? 8 : 24)

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
                            .frame(width: compact ? 150 : 180, height: compact ? 150 : 180)
                            .shadow(color: AppTheme.accent.opacity(0.4), radius: 12, y: 6)

                        Text(loc.t("zikir_tap", fallback: "Çek"))
                            .font(AppTheme.title(28, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(ZikirButtonStyle())
                .padding(.vertical, compact ? 4 : 12)

                Text(loc.t("zikir_hint", fallback: "Zikir çekmek için düğmeye dokun"))
                    .font(AppTheme.body(12))
                    .foregroundStyle(AppTheme.textTertiary(colorScheme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, compact ? 0 : 8)
                    .padding(.bottom, compact ? 8 : 16)

                // Grubun altında da aynı boşluk: grup ekranın ortasında durur.
                Spacer(minLength: 0)
                }
                .padding(.bottom, compact ? 8 : 16)
                // İçerik en az ekran boyu kadar uzasın; böylece Spacer çalışır,
                // içerik sığmazsa (ör. klavye açıkken) yine kaydırılabilir.
                .frame(minHeight: geo.size.height)
            }
            }
            .scrollDismissesKeyboard(.interactively)
            // Ekranın ortasında normal bir uyarı (iOS 26'da onay menüsü en altta açılıyordu).
            .alert(loc.t("zikir_reset_confirm_title", fallback: "Sayaç sıfırlansın mı?"),
                   isPresented: $showResetConfirm) {
                Button(loc.t("zikir_reset", fallback: "Sıfırla"), role: .destructive) { reset() }
                Button(loc.t("primer_later", fallback: "Şimdi değil"), role: .cancel) {}
            } message: {
                Text(loc.tf("zikir_reset_confirm_body", "Şu anki sayı (%d) ve bu moddaki tamamlanan turlar silinecek.", count))
            }
            .background(AppTheme.background(colorScheme).ignoresSafeArea())
            .navigationTitle(loc.t("tab_zikirmatik", fallback: "Zikirmatik"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func increment() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let phaseBefore = Tesbihat.phase(for: count).index
        count += 1
        // Tesbihatta bir kelimeden ötekine geçerken ayrıca belirgin titreşim.
        if goalMode == .tesbihat, count < Tesbihat.total, Tesbihat.phase(for: count).index != phaseBefore {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
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
