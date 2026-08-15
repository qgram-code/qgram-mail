import SwiftUI

@MainActor
struct MessageView: View {
    @EnvironmentObject private var store: MailStore
    @EnvironmentObject private var settings: SettingsStore

    private var accent: AccentTheme { settings.accent }

    private let quickReplies = ["Спасибо!", "Принято, посмотрю сегодня", "Давайте созвонимся"]

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            if let message = store.openMessage {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        heading(message)
                        sender(message)
                        bodyCard(message)
                        attachments(message)
                        quickReplyBlock(message)
                        Color.clear.frame(height: 150)
                    }
                }
                .overlay(alignment: .bottom) { replyBar(message) }
            } else {
                VStack(spacing: 12) {
                    ProgressView().tint(accent.base)
                    Text("Загружаем письмо…")
                        .font(.system(size: 13.5))
                        .foregroundStyle(QM.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(QM.bg)
        .sheet(isPresented: $store.attachmentsOpen) {
            AttachmentsSheet(attachments: store.openMessage?.attachments ?? [], accent: accent)
                .presentationDetents([.medium])
                .preferredColorScheme(.dark)
        }
    }

    // MARK: - Верхняя панель

    private var toolbar: some View {
        HStack(spacing: 4) {
            ChromeButton(title: store.folderLabel, systemImage: "chevron.left", color: accent.base) {
                store.backToList()
            }
            Spacer(minLength: 8)
            if let message = store.openMessage {
                let row = summary(of: message)
                toolbarButton("archivebox", tint: accent.base) { store.act("archive", on: row) }
                toolbarButton("exclamationmark.triangle", tint: accent.base) { store.act("spam", on: row) }
                toolbarButton("trash", tint: QM.danger) { store.act("delete", on: row) }
                toolbarButton("envelope.badge", tint: accent.base) { store.markOpenUnread() }
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

    /// Строка списка для действий над открытым письмом.
    private func summary(of message: MailMessageDetail) -> MailMessage {
        MailMessage(
            num: message.num, folder: message.folder, seen: true, flagged: false,
            fromName: message.fromName, fromAddress: message.fromAddress, to: message.to,
            subject: message.subject, date: message.date, rawDate: message.rawDate
        )
    }

    // MARK: - Тема и метки проверки подлинности

    private func heading(_ message: MailMessageDetail) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(message.displaySubject)
                .font(.system(size: 23, weight: .semibold))
                .tracking(-0.46)
                .lineSpacing(4)
                .foregroundStyle(QM.title)
                .fixedSize(horizontal: false, vertical: true)

            if !message.chips.isEmpty || message.spamFlag {
                FlowRow(spacing: 6) {
                    if message.spamFlag {
                        chip(text: "Помечено как спам", symbol: "exclamationmark.triangle", color: QM.warnText)
                    }
                    ForEach(message.chips) { item in
                        chip(text: item.label, symbol: "checkmark.shield", color: QM.text)
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
    }

    private func chip(text: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 11.5, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .overlay(Capsule().strokeBorder(QM.border, lineWidth: 1))
    }

    // MARK: - Отправитель

    private func sender(_ message: MailMessageDetail) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Avatar(name: message.displayName, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(message.displayName)
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(QM.title)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(message.time)
                        .font(.system(size: 12.5))
                        .foregroundStyle(QM.tertiary)
                }
                Text(message.fromAddress)
                    .font(.system(size: 12.5, design: .monospaced))
                    .foregroundStyle(QM.secondary)
                    .lineLimit(1)
                Text("Кому: \(message.to)")
                    .font(.system(size: 12.5))
                    .foregroundStyle(QM.tertiary)
                    .lineLimit(2)
                if !message.cc.isEmpty {
                    Text("Копия: \(message.cc)")
                        .font(.system(size: 12.5))
                        .foregroundStyle(QM.tertiary)
                        .lineLimit(2)
                }
            }
        }
        .padding(14)
        .qmCard()
        .padding(.horizontal, 14)
        .padding(.top, 14)
    }

    // MARK: - Текст письма

    private func bodyCard(_ message: MailMessageDetail) -> some View {
        Text(message.body.isEmpty ? "Письмо без текста." : message.body)
            .font(.system(size: 15.5))
            .lineSpacing(6)
            .foregroundStyle(QM.body)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .qmCard()
            .padding(.horizontal, 14)
            .padding(.top, 12)
    }

    // MARK: - Вложения

    @ViewBuilder
    private func attachments(_ message: MailMessageDetail) -> some View {
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

    private func quickReplyBlock(_ message: MailMessageDetail) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionCaption(text: "Быстрый ответ")
            FlowRow(spacing: 8) {
                ForEach(quickReplies, id: \.self) { reply in
                    Button {
                        store.reply(to: message, body: reply)
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

    private func replyBar(_ message: MailMessageDetail) -> some View {
        HStack(spacing: 9) {
            Button {
                store.reply(to: message)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrowshape.turn.up.left").font(.system(size: 15))
                    Text("Ответить…").font(.system(size: 15))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(QM.tertiary)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(QM.fill, in: Capsule())
                .overlay(Capsule().strokeBorder(QM.borderStrong, lineWidth: 1))
            }
            .buttonStyle(TapScaleStyle(scale: 0.98))

            Button {
                store.reply(to: message)
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
                Text(attachment.filename)
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
                .fill(QM.fill)
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

            Text("API отдаёт только имя, тип и размер вложения — скачать файл можно в почтовом клиенте по IMAP.")
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
