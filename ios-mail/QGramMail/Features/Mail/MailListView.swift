import SwiftUI

@MainActor
struct MailListView: View {
    @EnvironmentObject private var store: MailStore
    @EnvironmentObject private var settings: SettingsStore

    private var accent: AccentTheme { settings.accent }

    var body: some View {
        VStack(spacing: 0) {
            header

            if settings.demoBlocked {
                blockedBanner
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
            }

            // Плашку с квотой можно выключить в настройках.
            if settings.showQuota && !settings.demoBlocked {
                QuotaBar(sent: store.sentToday, limit: settings.dailyLimit, accent: accent)
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            list
        }
        .background(QM.bg)
        .animation(.easeInOut(duration: 0.22), value: settings.showQuota)
    }

    // MARK: - Шапка

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                ChromeButton(title: "Ящики", systemImage: "chevron.left", color: accent.base) {
                    store.go(to: .folders)
                }
                Spacer()
                ChromeButton(title: "Изм.", color: accent.base) {
                    store.flash("Режим выбора писем — в следующей итерации")
                }
            }
            .frame(height: 32)

            LargeTitle(text: store.folderLabel, trailing: store.folderCountLabel)
                .padding(.top, 6)

            Button {
                store.go(to: .search)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").font(.system(size: 15, weight: .medium))
                    Text("Поиск в письмах").font(.system(size: 16))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(QM.tertiary)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(QM.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(TapScaleStyle(scale: 0.98))
            .padding(.top, 12)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 10)
        .qmChromeBackground(edge: .top)
    }

    private var blockedBanner: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 14))
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text("Отправка писем с этого адреса приостановлена модерацией.")
                Button("Подробнее") { store.go(to: .blocked) }
                    .buttonStyle(.plain)
                    .underline()
            }
            .font(.system(size: 12.5))
            Spacer(minLength: 0)
        }
        .foregroundStyle(QM.warnText)
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(QM.warn.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(QM.warn.opacity(0.28), lineWidth: 1)
        )
    }

    // MARK: - Список писем

    private var list: some View {
        List {
            ForEach(store.currentFolderMessages) { message in
                row(for: message)
            }

            if store.currentFolderMessages.isEmpty {
                emptyState
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(QM.bg)
                    .listRowSeparator(.hidden)
            }

            Text("Обновлено только что · \(store.unseenInbox) непрочитанных")
                .font(.system(size: 12.5))
                .foregroundStyle(QM.faint)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
                .padding(.bottom, 120)
                .listRowInsets(EdgeInsets())
                .listRowBackground(QM.bg)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(QM.bg)
        .environment(\.defaultMinListRowHeight, 0)
        .refreshable { await store.refresh() }
    }

    @ViewBuilder
    private func row(for message: Message) -> some View {
        let base = MailRow(message: message, groupThreads: settings.groupThreads, accent: accent)
            .contentShape(Rectangle())
            .onTapGesture { store.open(message) }
            .listRowInsets(EdgeInsets(top: 11, leading: 8, bottom: 12, trailing: 14))
            .listRowBackground(QM.bg)
            .listRowSeparatorTint(QM.hairline)
            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }

        if settings.swipesEnabled {
            base
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button {
                        store.move(message.id, to: "Trash", toast: "Письмо удалено")
                    } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                    .tint(QM.deleteSwipe)

                    Button {
                        store.move(message.id, to: "Archive", toast: "Письмо в архиве")
                    } label: {
                        Label("Архив", systemImage: "archivebox")
                    }
                    .tint(QM.archiveSwipe)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        store.toggleSeen(message.id)
                    } label: {
                        Label(message.seen ? "Непрочитано" : "Прочитано", systemImage: "envelope.badge")
                    }
                    .tint(accent.base)
                }
        } else {
            base
        }
    }

    private var emptyState: some View {
        VStack(spacing: 4) {
            Image(systemName: "tray")
                .font(.system(size: 46, weight: .thin))
                .foregroundStyle(accent.base.opacity(0.5))
                .padding(.bottom, 14)
                .modifier(FloatAnimation())
            Text("Здесь пока пусто")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(QM.bright)
            Text("Новые письма появятся в этом списке.")
                .font(.system(size: 13.5))
                .foregroundStyle(QM.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 78)
        .padding(.horizontal, 26)
        .multilineTextAlignment(.center)
    }
}

/// Медленное «покачивание» иконки пустого состояния (в макете — @keyframes qmfloat).
private struct FloatAnimation: ViewModifier {
    @State private var up = false

    func body(content: Content) -> some View {
        content
            .offset(y: up ? -7 : 0)
            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: up)
            .onAppear { up = true }
    }
}

/// Строка списка писем.
@MainActor
struct MailRow: View {
    let message: Message
    let groupThreads: Bool
    let accent: AccentTheme

    private var threadCount: Int {
        groupThreads && message.thread.count > 1 ? message.thread.count : 0
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(accent.base)
                .frame(width: 8, height: 8)
                .opacity(message.seen ? 0 : 1)
                .frame(width: 12, alignment: .center)
                .padding(.top, 16)

            Avatar(name: message.name)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(message.name)
                        .font(.system(size: 16, weight: .semibold))
                        .tracking(-0.16)
                        .foregroundStyle(QM.title)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(message.time)
                        .font(.system(size: 13))
                        .foregroundStyle(QM.tertiary)
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(QM.chevron)
                }

                Text(message.subject)
                    .font(.system(size: 15))
                    .foregroundStyle(QM.subject)
                    .lineLimit(1)

                Text(message.preview)
                    .font(.system(size: 14))
                    .lineSpacing(2)
                    .foregroundStyle(QM.tertiary)
                    .lineLimit(2)

                if !message.attachments.isEmpty || threadCount > 0 || message.flagged {
                    HStack(spacing: 6) {
                        if !message.attachments.isEmpty {
                            Pill {
                                HStack(spacing: 4) {
                                    Image(systemName: "paperclip").font(.system(size: 9, weight: .semibold))
                                    Text("\(message.attachments.count)")
                                }
                            }
                        }
                        if threadCount > 0 {
                            Pill { Text("\(threadCount) письма в переписке") }
                        }
                        if message.flagged {
                            Text("★").font(.system(size: 12)).foregroundStyle(QM.warn)
                        }
                    }
                    .padding(.top, 5)
                }
            }
        }
    }
}

/// Маленькая метка-«таблетка» под письмом.
@MainActor
private struct Pill<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(QM.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .overlay(Capsule().strokeBorder(QM.borderStrong, lineWidth: 1))
    }
}
