import SwiftUI

/// Экран «отправка приостановлена» — состояние `state: nosend | blocked`
/// из `GET /api/mail/account`.
@MainActor
struct BlockedView: View {
    @EnvironmentObject private var store: MailStore
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var session: Session

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
            .refreshable { await session.loadAccount() }
        }
        .background(QM.bg)
    }

    private var card: some View {
        VStack(spacing: 0) {
            Image(systemName: "paperplane.slash")
                .font(.system(size: 58, weight: .ultraLight))
                .foregroundStyle(QM.warn)
                .padding(.bottom, 14)

            Text(session.account?.moderationBlocked == true ? "Ящик заблокирован" : "Отправка приостановлена")
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
                Text(session.address)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(QM.text)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(QM.bg, in: Capsule())
            .overlay(Capsule().strokeBorder(QM.border, lineWidth: 1))
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
                    Task {
                        await session.loadAccount()
                        store.flash(session.sendingBlocked ? "Ограничение всё ещё действует" : "Отправка снова доступна")
                    }
                } label: {
                    Text("Обновить статус")
                        .font(.system(size: 14.5, weight: .medium))
                        .foregroundStyle(QM.bright)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .strokeBorder(QM.borderStrong, lineWidth: 1)
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
            detailRow("Статус", statusText)
            HairLine()
            detailRow("Причина", session.blockReason ?? "Не указана")
            HairLine()
            detailRow("Отправлено", "\(session.sentToday) из \(session.dailyLimit) за сегодня")
        }
        .background(QM.bg)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(QM.border, lineWidth: 1)
        )
    }

    private var statusText: String {
        switch session.account?.state {
        case "blocked": return "Ящик заблокирован модерацией"
        case "nosend": return "Ограничение на отправку"
        default: return session.sendingBlocked ? "Ограничение на отправку" : "Активен"
        }
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
