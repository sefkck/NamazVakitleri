import SwiftUI

/// Kur'an dinlenirken başka sekmeye geçilince görünen küçük çalar.
/// Dokununca Kur'an sekmesine döner; oynat/duraklat ve durdur düğmeleri var.
struct MiniPlayerBar: View {
    @ObservedObject private var recitation = RecitationPlayer.shared
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var typeSize
    let onOpen: () -> Void

    var body: some View {
        if recitation.sourceID != nil {
            HStack(spacing: 12) {
                // Dokununca Kur'an sekmesine döner (VoiceOver'da da düğme olarak okunur).
                Button(action: onOpen) {
                    HStack(spacing: 12) {
                        Image(systemName: "book.fill")
                            .foregroundColor(AppTheme.accent)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(recitation.sourceTitle ?? "")
                                .font(AppTheme.body(14, weight: .semibold))
                                .foregroundColor(AppTheme.textPrimary(colorScheme))
                                .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
                            if let i = recitation.currentIndex {
                                Text(loc.tf("recitation_now", "%d. ayet okunuyor", i + 1))
                                    .font(AppTheme.body(12))
                                    .foregroundColor(AppTheme.textSecondary(colorScheme))
                            }
                        }
                        Spacer(minLength: 4)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(loc.t("recitation_open_hint", fallback: "Kur'an sekmesine döner"))
                Button {
                    recitation.isPlaying ? recitation.pause() : recitation.resume()
                } label: {
                    Image(systemName: recitation.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .bold))
                        .frame(width: 44, height: 44)
                        .foregroundColor(AppTheme.accent)
                }
                .accessibilityLabel(recitation.isPlaying ? loc.t("recitation_pause", fallback: "Duraklat") : loc.t("quran_listen", fallback: "Dinle"))
                Button { recitation.stop() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 40, height: 44)
                        .foregroundColor(AppTheme.textSecondary(colorScheme))
                }
                .accessibilityLabel(loc.t("quran_stop", fallback: "Durdur"))
            }
            .padding(.leading, 14)
            .padding(.trailing, 4)
            .background(RoundedRectangle(cornerRadius: 16).fill(.regularMaterial))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardStroke(colorScheme), lineWidth: 1))
            .padding(.horizontal, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
