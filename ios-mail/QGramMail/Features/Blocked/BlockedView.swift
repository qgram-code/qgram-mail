import SwiftUI

@MainActor
struct BlockedView: View {
    @EnvironmentObject private var store: MailStore
    @EnvironmentObject private var settings: SettingsStore

    private var accent: AccentTheme { settings.accent }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                ChromeButton(title: "Входящие", systemImage: "chevron.left", color: accent.base) {
                    store.openInbox()
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 9)

            ScrollView {
                card
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 60)
            }
        }
        .background(QM.bg)
    }

    private var card: some View {
        VStack(spacing: 0) {
            Image(systemName: "paperplane.slash")
                .font(.system(size: 58, weight: .ultraLight))
                .foregroundStyle(QM.warn)
                .padding(.bottom, 14)

            Text("Отправка приостановлена")
                .font(.system(size: 21, weight: .semibold))
                .tracking(-0.42)
                .foregroundStyle(QM.warn)

            Text("Входящие письма продолжают приходить, но отправлять с этого адреса сейчас нельзя.")
                .font(.system(size: 14))
                .lineSpacing(4)
                .foregroundStyle(QM.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 9)

            HStack(spacing: 8) {
                Circle().fill(QM.warn).frame(width: 7, height: 7)
                Text(settings.address)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(QM.text)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(QM.bg, in: Capsule())
            .overlay(Capsule().strokeBorder(Color(hex: "E9E9ED").opacity(0.10), lineWidth: 1))
            .padding(.top, 15)

            details.padding(.top, 18)

            HStack(spacing: 9) {
                Button {
                    store.openInbox()
                } label: {
                    Text("Открыть входящие")
                        .font(.system(size: 14.5, weight: .medium))
                        .foregroundStyle(accent.tint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(accent.soft, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .strokeBorder(accent.base, lineWidth: 1)
                        )
                }
                .buttonStyle(TapScaleStyle(scale: 0.97))

                Button {
                    store.flash("Обращение отправлено в поддержку")
                } label: {
                    Text("В поддержку")
                        .font(.system(size: 14.5, weight: .medium))
                        .foregroundStyle(QM.bright)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .strokeBorder(Color(hex: "E9E9ED").opacity(0.14), lineWidth: 1)
                        )
                }
                .buttonStyle(TapScaleStyle(scale: 0.97))
            }
            .padding(.top, 16)

            Text("Ограничение накладывается модерацией QGram — обычно из-за рассылок, жалоб на спам или нарушения правил. Аккаунт QGram при этом продолжает работать.")
                .font(.system(size: 12))
                .lineSpacing(3)
                .foregroundStyle(QM.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 16)
        }
        .padding(.horizontal, 20)
        .padding(.top, 26)
        .padding(.bottom, 22)
        .background(
            LinearGradient(
                colors: [QM.warn.opacity(0.10), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .background(QM.card)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(QM.warn.opacity(0.32), lineWidth: 1)
        )
    }

    private var details: some View {
        VStack(spacing: 0) {
            detailRow("Статус", "Ограничение на отправку")
            HairLine()
            detailRow("Причина", "Жалобы на массовую рассылку")
            HairLine()
            detailRow("С", "14 августа, 11:20")
        }
        .background(QM.bg)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(QM.border, lineWidth: 1)
        )
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title)
                .foregroundStyle(QM.tertiary)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .foregroundStyle(QM.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 13.5))
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
    }
}
