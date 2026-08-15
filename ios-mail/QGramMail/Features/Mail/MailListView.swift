import SwiftUI

@MainActor
struct MailListView: View {
    @EnvironmentObject private var store: MailStore
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var session: Session

    private var accent: AccentTheme { settings.accent }

    var body: some View {
        VStack(spacing: 0) {
            header

            if session.sendingBlocked {
                blockedBanner
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
            }

            if let error = store.listError {
                errorBanner(error)
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
            }

            // Плашку с квотой можно выключить в настройках.
            if settings.showQuota && !session.sendingBlocked {
                QuotaBar(sent: session.sentToday, limit: session.dailyLimit, accent: accent)
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            list
        }
        .background(QM.bg)
        .animation(.easeInOut(duration: 0.22), value: settings.showQuota)
        .task { await store.loadIfNeeded() }
    }

    // MARK: - Шапка

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                ChromeButton(title: "Ящики", systemImage: "chevron.left", color: accent.base) {
                    store.go(to: .folders)
                }
                Spacer()
                if store.loading {
                    ProgressView().tint(QM.tertiary)
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

    private func errorBanner(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 14))
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 12.5))
                .lineSpacing(3)
            Spacer(minLength: 0)
            Button("Ещё раз") { Task { await store.load(reset: true) } }
                .font(.system(size: 12.5, weight: .medium))
                .buttonStyle(.plain)
        }
        .foregroundStyle(QM.danger)
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(QM.danger.opacity(0.09), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(QM.danger.opacity(0.26), lineWidth: 1)
        )
    }

    // MARK: - Список писем

    private var list: some View {
        List {
            ForEach(store.messages) { message in
                row(for: message)
            }

            if store.messages.isEmpty && !store.loading {
                emptyState
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(QM.bg)
                    .listRowSeparator(.hidden)
            }

            footer
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
    private var footer: some View {
        VStack(spacing: 10) {
            if store.canLoadMore {
                Button {
                    Task { await store.loadMore() }
                } label: {
                    if store.loadingMore {
                        ProgressView().tint(QM.tertiary)
                    } else {
                        Text("Показать ещё")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(accent.base)
                    }
                }
                .buttonStyle(TapScaleStyle(scale: 0.96))
            }

            if !store.messages.isEmpty {
                Text("\(store.messages.count) из \(max(store.total, store.messages.count)) · \(store.unseenInbox) непрочитанных")
                    .font(.system(size: 12.5))
                    .foregroundStyle(QM.faint)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
        .padding(.bottom, 120)
    }

    @ViewBuilder
    private func row(for message: MailMessage) -> some View {
        let base = MailRow(message: message, preview: store.preview(for: message), accent: accent)
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
                        store.act("delete", on: message)
                    } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                    .tint(QM.deleteSwipe)

                    Button {
                        store.act("archive", on: message)
                    } label: {
                        Label("Архив", systemImage: "archivebox")
                    }
                    .tint(QM.archiveSwipe)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        store.act(message.seen ? "unread" : "read", on: message)
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
            Image(systemName: MailFolder.symbol(for: store.folder))
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
    let message: MailMessage
    let preview: String?
    let accent: AccentTheme

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(accent.base)
                .frame(width: 8, height: 8)
                .opacity(message.seen ? 0 : 1)
                .frame(width: 12, alignment: .center)
                .padding(.top, 16)

            Avatar(name: message.displayName)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(message.displayName)
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

                Text(message.displaySubject)
                    .font(.system(size: 15))
                    .foregroundStyle(QM.subject)
                    .lineLimit(1)

                if let preview, !preview.isEmpty {
                    Text(preview)
                        .font(.system(size: 14))
                        .lineSpacing(2)
                        .foregroundStyle(QM.tertiary)
                        .lineLimit(2)
                } else {
                    Text(message.fromAddress)
                        .font(.system(size: 13))
                        .foregroundStyle(QM.faint)
                        .lineLimit(1)
                }

                if message.flagged {
                    Text("★")
                        .font(.system(size: 12))
                        .foregroundStyle(QM.warn)
                        .padding(.top, 5)
                }
            }
        }
    }
}
