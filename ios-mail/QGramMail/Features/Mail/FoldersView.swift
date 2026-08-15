import SwiftUI

@MainActor
struct FoldersView: View {
    @EnvironmentObject private var store: MailStore
    @EnvironmentObject private var settings: SettingsStore

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
        }
        .background(QM.bg)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Аккаунт")
                    .font(.system(size: 17))
                    .foregroundStyle(QM.faint)
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
                Circle().fill(QM.online).frame(width: 7, height: 7)
                Text(settings.address)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(QM.bright)
            }

            HStack {
                Text("Занято в ящике")
                Spacer()
                Text("1,8 ГБ из 5 ГБ")
            }
            .font(.system(size: 12))
            .foregroundStyle(QM.tertiary)
            .padding(.top, 12)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(QM.track)
                    Capsule().fill(accent.base).frame(width: geo.size.width * 0.36)
                }
            }
            .frame(height: 4)
            .padding(.top, 7)
        }
        .padding(14)
        .qmCard()
    }
}
