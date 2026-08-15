import SwiftUI

@MainActor
struct MessageView: View {
    @EnvironmentObject private var store: MailStore
    @EnvironmentObject private var settings: SettingsStore

    private var accent: AccentTheme { settings.accent }

    private let quickReplies = ["Спасибо!", "Принято, посмотрю сегодня", "Давайте созвонимся"]

    var body: some View {
        Group {
            if let message = store.openMessage {
                VStack(spacing: 0) {
                    toolbar
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            heading(message)
                            thread(message)
                            attachments(message)
                            quickReplyBlock(message)
                            Color.clear.frame(height: 150)
                        }
                    }
                }
                .background(QM.bg)
                .overlay(alignment: .bottom) { replyBar(message) }
                .sheet(isPresented: $store.attachmentsOpen) {
                    AttachmentsSheet(attachments: message.attachments, accent: accent)
                        .presentationDetents([.medium])
                        .preferredColorScheme(.dark)
                }
            } else {
                Color.clear.onAppear { store.openInbox() }
            }
        }
    }

    // MARK: - Верхняя панель

    private var toolbar: some View {
        HStack(spacing: 4) {
            ChromeButton(title: store.folderLabel, systemImage: "chevron.left", color: accent.base) {
                store.openInbox()
            }
            Spacer(minLength: 8)
            toolbarButton("archivebox", tint: accent.base) {
                store.move(store.openID ?? -1, to: "Archive", toast: "Письмо в архиве")
            }
            toolbarButton("exclamationmark.triangle", tint: accent.base) {
                store.move(store.openID ?? -1, to: "Junk", toast: "Отмечено как спам")
            }
            toolbarButton("trash", tint: QM.danger) {
                store.move(store.openID ?? -1, to: "Trash", toast: "Письмо удалено")
            }
            toolbarButton("envelope.badge", tint: accent.base) {
                store.markOpenUnread()
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 9)
        .qmChromeBackground(edge: .top)
    }

    private func toolbarButton(_ symbol: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(TapScaleStyle(scale: 0.88))
    }

    // MARK: - Тема и метки проверки подлинности

    private func heading(_ message: Message) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(message.subject)
                .font(.system(size: 23, weight: .semibold))
                .tracking(-0.46)
                .lineSpacing(4)
                .foregroundStyle(QM.title)
                .fixedSize(horizontal: false, vertical: true)

            if !message.chips.isEmpty {
                FlowRow(spacing: 6) {
                    ForEach(message.chips) { chip in
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.shield")
                                .font(.system(size: 10, weight: .semibold))
                            Text(chip.label)
                                .font(.system(size: 11.5, weight: .semibold))
                        }
                        .foregroundStyle(QM.text)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .overlay(Capsule().strokeBorder(Color(hex: "E9E9ED").opacity(0.10), lineWidth: 1))
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
    }

    // MARK: - Переписка

    private func thread(_ message: Message) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(message.thread.enumerated()), id: \.element.id) { index, entry in
                let isExpanded = store.expanded.contains(index)
                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { store.toggleExpanded(index) }
                    } label: {
                        HStack(alignment: .top, spacing: 11) {
                            Avatar(name: entry.name, size: 38)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text(entry.name)
                                        .font(.system(size: 15.5, weight: .semibold))
                                        .foregroundStyle(QM.title)
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                    Text(entry.time)
                                        .font(.system(size: 12.5))
                                        .foregroundStyle(QM.tertiary)
                                }
                                Text("Кому: \(entry.to)")
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(QM.tertiary)
                                    .lineLimit(1)
                                if !isExpanded {
                                    Text(entry.body)
                                        .font(.system(size: 14))
                                        .lineSpacing(2)
                                        .foregroundStyle(Color(hex: "8A8E9F"))
                                        .lineLimit(2)
                                        .padding(.top, 4)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if isExpanded {
                        Text(entry.body)
                            .font(.system(size: 15.5))
                            .lineSpacing(6)
                            .foregroundStyle(QM.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                    }
                }
                .qmCard()
                .padding(.horizontal, 14)
                .padding(.top, 14)
            }
        }
    }

    // MARK: - Вложения

    @ViewBuilder
    private func attachments(_ message: Message) -> some View {
        if !message.attachments.isEmpty {
            VStack(alignment: .leading, spacing: 9) {
                SectionCaption(text: "Вложения (\(message.attachments.count))")
                VStack(spacing: 8) {
                    ForEach(message.attachments) { attachment in
                        Button {
                            store.attachmentsOpen = true
                        } label: {
                            AttachmentRow(attachment: attachment, accent: accent, showsChevron: true)
                        }
                        .buttonStyle(TapScaleStyle(scale: 0.98))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 16)
        }
    }

    // MARK: - Быстрый ответ

    private func quickReplyBlock(_ message: Message) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionCaption(text: "Быстрый ответ")
            FlowRow(spacing: 8) {
                ForEach(quickReplies, id: \.self) { reply in
                    Button {
                        store.compose(to: message.address, subject: "Re: \(message.subject)", body: reply)
                    } label: {
                        Text(reply)
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(accent.tint)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(accent.softer, in: Capsule())
                            .overlay(Capsule().strokeBorder(accent.line, lineWidth: 1))
                    }
                    .buttonStyle(TapScaleStyle(scale: 0.95))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 18)
    }

    // MARK: - Нижняя панель ответа

    private func replyBar(_ message: Message) -> some View {
        HStack(spacing: 9) {
            Button {
                store.compose(to: message.address, subject: "Re: \(message.subject)")
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrowshape.turn.up.left").font(.system(size: 15))
                    Text("Ответить…").font(.system(size: 15))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(QM.tertiary)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Color(hex: "E9E9ED").opacity(0.06), in: Capsule())
                .overlay(Capsule().strokeBorder(QM.borderStrong, lineWidth: 1))
            }
            .buttonStyle(TapScaleStyle(scale: 0.98))

            Button {
                store.compose(to: message.address, subject: "Re: \(message.subject)")
            } label: {
                Image(systemName: "paperplane")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(QM.bg)
                    .frame(width: 44, height: 44)
                    .background(accent.base, in: Circle())
            }
            .buttonStyle(TapScaleStyle(scale: 0.92))
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .qmChromeBackground(edge: .bottom)
    }
}

/// Строка вложения (карточка с расширением файла, именем и размером).
@MainActor
struct AttachmentRow: View {
    let attachment: MailAttachment
    let accent: AccentTheme
    var showsChevron = false

    var body: some View {
        HStack(spacing: 11) {
            Text(attachment.ext)
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(accent.base)
                .frame(width: 36, height: 36)
                .background(accent.soft, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.name)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(QM.text)
                    .lineLimit(1)
                Text(attachment.meta)
                    .font(.system(size: 11.5))
                    .foregroundStyle(QM.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(QM.chevron)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(QM.card)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(QM.border, lineWidth: 1)
        )
    }
}

/// Шторка со списком вложений.
@MainActor
struct AttachmentsSheet: View {
    let attachments: [MailAttachment]
    let accent: AccentTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(Color(hex: "E9E9ED").opacity(0.2))
                .frame(width: 38, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 16)

            Text("Вложения (\(attachments.count))")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(QM.text)

            VStack(spacing: 9) {
                ForEach(attachments) { attachment in
                    AttachmentRow(attachment: attachment, accent: accent)
                }
            }
            .padding(.top, 13)

            Text("Скачивание вложений доступно в почтовом клиенте по IMAP.")
                .font(.system(size: 12.5))
                .lineSpacing(3)
                .foregroundStyle(QM.tertiary)
                .padding(.top, 13)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(QM.sheet)
    }
}

/// Простая раскладка «в строку с переносом» — аналог flex-wrap из макета.
struct FlowRow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
