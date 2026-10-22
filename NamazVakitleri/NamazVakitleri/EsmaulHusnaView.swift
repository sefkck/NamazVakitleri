import SwiftUI

/// Esmâ-i Hüsnâ listesi; en üstte "günün ismi".
struct EsmaulHusnaView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @Environment(\.dynamicTypeSize) private var typeSize

    private var filtered: [EsmaulHusna.Name] {
        search.isEmpty ? EsmaulHusna.all : EsmaulHusna.all.filter {
            $0.turkish.matchesSearch(search) || $0.latin.matchesSearch(search)
                || ($0.meaning ?? "").matchesSearch(search) || $0.arabic.contains(search)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if search.isEmpty {
                    Section(loc.t("esma_today", fallback: "Günün ismi")) {
                        row(EsmaulHusna.nameOfDay(), number: nil, big: true)
                    }
                }
                Section {
                    ForEach(filtered) { name in
                        row(name, number: (EsmaulHusna.all.firstIndex { $0.id == name.id } ?? 0) + 1, big: false)
                    }
                }
            }
            .searchable(text: $search, prompt: loc.t("esma_search", fallback: "İsim ya da anlam ara"))
            .scrollContentBackground(.hidden)
            .background(AppTheme.background(colorScheme).ignoresSafeArea())
            .navigationTitle(loc.t("esma_title", fallback: "Esmâ-i Hüsnâ"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }
                    .accessibilityLabel(loc.t("common_close", fallback: "Kapat"))
                }
            }
        }
    }

    /// VoiceOver Arapça ismi Arapça sesle okusun.
    private static func arabicSpoken(_ text: String) -> AttributedString {
        var a = AttributedString(text)
        a.languageIdentifier = "ar"
        return a
    }

    private func row(_ name: EsmaulHusna.Name, number: Int?, big: Bool) -> some View {
        // Çok büyük yazıda Arapça isim alta iner (yan yana sığmıyor).
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        return layout {
            if let number {
                Text("\(number)")
                    .font(AppTheme.body(12, weight: .semibold))
                    .foregroundColor(AppTheme.textTertiary(colorScheme))
                    .frame(minWidth: 24, alignment: .trailing)
                    .fixedSize()
            }
            VStack(alignment: .leading, spacing: 3) {
                if loc.language != .arabic {
                    Text(name.displayName)
                        .font(AppTheme.body(big ? 18 : 15, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary(colorScheme))
                }
                if let meaning = name.meaning {
                    Text(meaning)
                        .font(AppTheme.body(big ? 15 : 13))
                        .foregroundColor(AppTheme.textSecondary(colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
            Text(Self.arabicSpoken(name.arabic))
                .font(.system(size: AppTheme.scaled(big ? 30 : 22)))
                .foregroundColor(AppTheme.accent)
                .environment(\.layoutDirection, .rightToLeft)
                .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : nil, alignment: .trailing)
        }
        .padding(.vertical, big ? 8 : 2)
        .listRowBackground(AppTheme.cardFill(colorScheme))
        .accessibilityElement(children: .combine)
    }
}
