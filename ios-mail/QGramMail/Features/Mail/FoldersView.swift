import SwiftUI

@MainActor
struct FoldersView: View {
    @EnvironmentObject private var store: MailStore
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var session: Session

    private var accent: AccentTheme { settings.accent }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 16) {
                    folderList
                    accountCard
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 140)
            }
            .refreshable { await store.loadCounts() }
        }
        .background(QM.bg)
        .task { await store.loadCounts() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(session.user?.displayName ?? "Аккаунт")
                    .font(.system(size: 17))
                    .foregroundStyle(QM.faint)
                    .lineLimit(1)
                Spacer()
                ChromeButton(title: "Готово", color: accent.base) { store.openInbox() }
            }
            .frame(height: 32)

            LargeTitle(text: "Ящики")
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) { HairLine() }
    }

    private var folderList: some View {
        VStack(spacing: 0) {
            ForEach(Array(MailFolder.all.enumerated()), id: \.element.id) { index, folder in
                Button {
                    store.pick(folder: folder.id)
                } label: {
                    let unseen = store.unseenCount(in: folder.id)
                    HStack(spacing: 12) {
                        Image(systemName: folder.symbol)
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(accent.base)
                            .frame(width: 22)
                        Text(folder.label)
                            .font(.system(size: 16.5))
                            .foregroundStyle(QM.text)
                        Spacer(minLength: 8)
                        Text("\(unseen > 0 ? unseen : store.count(in: folder.id))")
                            .font(.system(size: 12, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(unseen > 0 ? .white : QM.tertiary)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 2)
                            .background(unseen > 0 ? accent.base : QM.fill, in: Capsule())
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(QM.chevron)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .background(folder.id == store.folder ? accent.soft : Color.clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if index < MailFolder.all.count - 1 { HairLine() }
            }
        }
        .qmCard()
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Circle()
                    .fill(session.sendingBlocked ? QM.warn : QM.online)
                    .frame(width: 7, height: 7)
                Text(session.address)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(QM.bright)
                Spacer(minLength: 0)
            }

            HStack {
                Text("Отправлено сегодня")
                Spacer()
                Text("\(session.sentToday) из \(session.dailyLimit)")
                    .monospacedDigit()
            }
            .font(.system(size: 12))
            .foregroundStyle(QM.tertiary)
            .padding(.top, 12)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(QM.track)
                    Capsule()
                        .fill(accent.base)
                        .frame(width: geo.size.width * quotaFraction)
                }
            }
            .frame(height: 4)
            .padding(.top, 7)

            Text("Всего писем в ящике: \(MailFolder.all.reduce(0) { $0 + store.count(in: $1.id) })")
                .font(.system(size: 12))
                .foregroundStyle(QM.faint)
                .padding(.top, 10)
        }
        .padding(14)
        .qmCard()
    }

    private var quotaFraction: Double {
        guard session.dailyLimit > 0 else { return 0 }
        return min(Double(session.sentToday) / Double(session.dailyLimit), 1)
    }
}
