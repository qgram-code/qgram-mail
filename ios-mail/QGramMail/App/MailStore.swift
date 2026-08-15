import SwiftUI

/// Состояние почты поверх qgram API: списки писем, открытое письмо,
/// действия, поиск, отправка. Никаких демо-данных — всё с сервера.
@MainActor
final class MailStore: ObservableObject {
    // Список
    @Published var folder = "INBOX"
    @Published var messages: [MailMessage] = []
    @Published var counts: [String: FolderCount] = [:]
    @Published var total = 0
    @Published var loading = false
    @Published var loadingMore = false
    @Published var listError: String?

    // Открытое письмо
    @Published var screen: Screen = .list
    @Published var openMessage: MailMessageDetail?
    @Published var openLoading = false
    @Published var attachmentsOpen = false

    // Написание
    @Published var composeOpen = false
    @Published var sending = false
    @Published var draft = MailDraft()

    // Поиск
    @Published var query = ""
    @Published var scope: SearchScope = .all
    @Published var searchResults: [MailMessage] = []
    @Published var searching = false

    /// Короткие превью писем (тело через `peek=1`) — по ключу «папка/номер».
    @Published var previews: [String: String] = [:]
    /// Подгружать ли превью (настройка «Показывать текст письма в списке»).
    var previewsEnabled = true

    @Published var toast: String?

    weak var session: Session?

    private let api = QGramAPI.shared
    private let perPage = 25
    private var page = 1
    private var toastTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?

    // MARK: - Выборки

    var folderLabel: String { MailFolder.label(for: folder) }

    var folderCountLabel: String {
        let value = counts[folder]?.total ?? total
        return value > 0 ? "\(value) писем" : ""
    }

    var unseenInbox: Int { counts["INBOX"]?.unseen ?? 0 }

    func unseenCount(in folderID: String) -> Int { counts[folderID]?.unseen ?? 0 }
    func count(in folderID: String) -> Int { counts[folderID]?.total ?? 0 }

    func preview(for message: MailMessage) -> String? { previews[message.id] }

    var showsTabBar: Bool {
        screen == .list || screen == .folders || screen == .settings
    }

    var canLoadMore: Bool { messages.count < total }

    // MARK: - Навигация

    func go(to screen: Screen) {
        withAnimation(.easeOut(duration: 0.18)) { self.screen = screen }
    }

    func openInbox() {
        openMessage = nil
        if folder != "INBOX" {
            folder = "INBOX"
            Task { await load(reset: true) }
        }
        go(to: .list)
    }

    func backToList() {
        openMessage = nil
        go(to: .list)
    }

    func pick(folder id: String) {
        Haptics.tap()
        guard id != folder else {
            go(to: .list)
            return
        }
        folder = id
        openMessage = nil
        messages = []
        total = 0
        go(to: .list)
        Task { await load(reset: true) }
    }

    // MARK: - Загрузка списка

    func loadIfNeeded() async {
        guard messages.isEmpty, !loading else { return }
        await load(reset: true)
    }

    func load(reset: Bool) async {
        if reset { page = 1 }
        loading = reset
        defer { loading = false }
        do {
            let response = try await api.messages(folder: folder, page: page, perPage: perPage)
            let items = response.messages.map { convert($0, folder: response.folder) }
            if reset {
                messages = items
            } else {
                let known = Set(messages.map(\.id))
                messages += items.filter { !known.contains($0.id) }
            }
            total = response.total ?? messages.count
            listError = nil
            schedulePreviews()
        } catch {
            listError = await describe(error)
        }
        await loadCounts()
    }

    func loadMore() async {
        guard !loadingMore, !loading, canLoadMore else { return }
        loadingMore = true
        defer { loadingMore = false }
        page += 1
        await load(reset: false)
    }

    func refresh() async {
        let before = counts["INBOX"]?.unseen ?? 0
        await load(reset: true)
        let after = counts["INBOX"]?.unseen ?? 0
        if listError == nil {
            flash(after > before ? "Новые письма" : "Новых писем нет")
        }
    }

    func loadCounts() async {
        do {
            let folders = try await api.folders()
            var map: [String: FolderCount] = [:]
            for item in folders {
                map[item.name] = FolderCount(total: item.total ?? 0, unseen: item.unseen ?? 0)
            }
            counts = map
        } catch {
            // Счётчики не критичны — молча оставляем прежние.
        }
    }

    // MARK: - Превью писем

    private func schedulePreviews() {
        previewTask?.cancel()
        guard previewsEnabled else { return }
        let targets = messages.prefix(12).filter { previews[$0.id] == nil }
        guard !targets.isEmpty else { return }
        previewTask = Task { [weak self] in
            guard let self else { return }
            for message in targets {
                if Task.isCancelled { return }
                guard let body = try? await self.api.message(
                    folder: message.folder, num: message.num, peek: true
                ).body else { continue }
                let text = MailStore.snippet(from: body)
                if Task.isCancelled { return }
                self.previews[message.id] = text
            }
        }
    }

    private static func snippet(from body: String) -> String {
        let cleaned = body
            .replacingOccurrences(of: "\r", with: "")
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix(">") }
            .joined(separator: " ")
        return String(cleaned.prefix(220))
    }

    // MARK: - Открытие письма

    func open(_ message: MailMessage) {
        Haptics.tap()
        openMessage = nil
        openLoading = true
        go(to: .message)
        markSeenLocally(message.id, seen: true)
        Task {
            defer { openLoading = false }
            do {
                let body = try await api.message(folder: message.folder, num: message.num)
                openMessage = convert(body, folder: message.folder)
                previews[message.id] = MailStore.snippet(from: body.body ?? "")
                await loadCounts()
            } catch {
                flash(await describe(error))
                backToList()
            }
        }
    }

    // MARK: - Действия над письмами

    func act(_ action: String, on message: MailMessage) {
        Haptics.tap()
        let removes = ["delete", "spam", "archive", "inbox"].contains(action)
        let previous = messages
        if removes {
            withAnimation(.easeInOut(duration: 0.22)) {
                messages.removeAll { $0.id == message.id }
            }
        } else if action == "read" || action == "unread" {
            markSeenLocally(message.id, seen: action == "read")
        } else if action == "star" || action == "unstar" {
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                messages[index].flagged = action == "star"
            }
        }
        if openMessage?.id == message.id, removes {
            backToList()
        }

        Task {
            do {
                let response = try await api.perform(
                    action: action, folder: message.folder, num: message.num
                )
                flash(MailStore.toastText(for: action, movedTo: response.movedTo))
                await loadCounts()
                if removes {
                    // Номера писем в IMAP смещаются после перемещения — перечитываем папку.
                    await load(reset: true)
                }
            } catch {
                messages = previous
                flash(await describe(error))
            }
        }
    }

    func markOpenUnread() {
        guard let open = openMessage else { return }
        let message = MailMessage(
            num: open.num, folder: open.folder, seen: true, flagged: false,
            fromName: open.fromName, fromAddress: open.fromAddress, to: open.to,
            subject: open.subject, date: open.date, rawDate: open.rawDate
        )
        backToList()
        act("unread", on: message)
    }

    private func markSeenLocally(_ id: String, seen: Bool) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].seen = seen
    }

    private static func toastText(for action: String, movedTo: String?) -> String {
        switch action {
        case "delete": return "Письмо удалено"
        case "spam": return "Отмечено как спам"
        case "archive": return "Письмо в архиве"
        case "inbox": return "Письмо во входящих"
        case "read": return "Помечено прочитанным"
        case "unread": return "Помечено непрочитанным"
        case "star": return "Отмечено флажком"
        case "unstar": return "Флажок снят"
        default: return movedTo.map { "Перемещено в \(MailFolder.label(for: $0))" } ?? "Готово"
        }
    }

    // MARK: - Поиск

    func runSearch() {
        searchTask?.cancel()
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2 else {
            searchResults = []
            searching = false
            return
        }
        searching = true
        searchTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
            let folders: [String]
            switch self.scope {
            case .all: folders = MailFolder.all.map(\.id)
            case .folder, .unread: folders = [self.folder]
            }
            var found: [MailMessage] = []
            for name in folders {
                if Task.isCancelled { return }
                guard let response = try? await self.api.messages(
                    folder: name, page: 1, perPage: 25, query: text
                ) else { continue }
                found += response.messages.map { self.convert($0, folder: name) }
            }
            if Task.isCancelled { return }
            if self.scope == .unread { found = found.filter { !$0.seen } }
            self.searchResults = found.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
            self.searching = false
        }
    }

    func clearSearch() {
        searchTask?.cancel()
        query = ""
        searchResults = []
        searching = false
    }

    // MARK: - Написание письма

    func compose(to recipient: String = "", subject: String = "", body: String = "", inReplyTo: String? = nil) {
        Haptics.tap()
        draft = MailDraft(to: recipient, cc: "", subject: subject, body: body, inReplyTo: inReplyTo)
        composeOpen = true
    }

    func composeNew() {
        guard session?.sendingBlocked != true else {
            flash("Отправка приостановлена модерацией")
            go(to: .blocked)
            return
        }
        compose()
    }

    func reply(to message: MailMessageDetail, body: String = "") {
        let subject = message.subject.lowercased().hasPrefix("re:")
            ? message.subject
            : "Re: \(message.displaySubject)"
        compose(to: message.fromAddress, subject: subject, body: body, inReplyTo: message.messageId)
    }

    func send() async {
        let recipients = MailStore.addresses(from: draft.to)
        guard !recipients.isEmpty else {
            flash("Укажите получателя")
            return
        }
        sending = true
        defer { sending = false }
        do {
            let response = try await api.sendMail(
                to: recipients,
                cc: MailStore.addresses(from: draft.cc),
                subject: draft.subject,
                body: draft.body,
                inReplyTo: draft.inReplyTo
            )
            Haptics.success()
            session?.applyQuota(sent: response.sentToday, limit: response.dailyLimit)
            composeOpen = false
            draft = MailDraft()
            flash("Письмо отправлено")
            await loadCounts()
            if folder == "Sent" { await load(reset: true) }
        } catch {
            flash(await describe(error))
        }
    }

    static func addresses(from raw: String) -> [String] {
        raw.split(whereSeparator: { ",;\n ".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.contains("@") }
    }

    // MARK: - Сброс при выходе

    func reset() {
        searchTask?.cancel()
        previewTask?.cancel()
        messages = []
        counts = [:]
        previews = [:]
        searchResults = []
        openMessage = nil
        total = 0
        page = 1
        folder = "INBOX"
        screen = .list
        listError = nil
        query = ""
    }

    // MARK: - Служебное

    private func convert(_ response: MailMessageResponse, folder: String) -> MailMessage {
        let raw = response.date ?? ""
        let from = response.from ?? ""
        return MailMessage(
            num: response.num.value,
            folder: folder,
            seen: response.seen ?? true,
            flagged: response.flagged ?? false,
            fromName: response.fromName ?? MailStore.name(from: from),
            fromAddress: MailStore.address(from: from),
            to: response.to ?? "",
            subject: response.subject ?? "",
            date: MailDate.parse(raw),
            rawDate: raw
        )
    }

    private func convert(_ body: MailMessageBody, folder: String) -> MailMessageDetail {
        let raw = body.date ?? ""
        let from = body.from ?? ""
        return MailMessageDetail(
            num: body.num.value,
            folder: folder,
            fromName: body.fromName ?? MailStore.name(from: from),
            fromAddress: body.fromAddr ?? MailStore.address(from: from),
            to: body.to ?? "",
            cc: body.cc ?? "",
            subject: body.subject ?? "",
            date: MailDate.parse(raw),
            rawDate: raw,
            messageId: body.messageId ?? "",
            body: body.body ?? "",
            attachments: (body.attachments ?? []).map {
                MailAttachment(
                    filename: $0.filename ?? "Вложение",
                    contentType: $0.contentType ?? "application/octet-stream",
                    size: $0.size ?? 0
                )
            },
            spamFlag: body.spamFlag ?? false,
            authResults: body.authResults ?? ""
        )
    }

    /// «Alice <alice@example.com>» → «Alice» / «alice@example.com».
    static func name(from header: String) -> String {
        guard let bracket = header.firstIndex(of: "<") else {
            return header.contains("@") ? "" : header.trimmingCharacters(in: .whitespaces)
        }
        return String(header[header.startIndex..<bracket])
            .trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))
    }

    static func address(from header: String) -> String {
        if let open = header.firstIndex(of: "<"), let close = header.firstIndex(of: ">"), open < close {
            return String(header[header.index(after: open)..<close]).trimmingCharacters(in: .whitespaces)
        }
        return header.trimmingCharacters(in: .whitespaces)
    }

    /// Приводит ошибку к тексту для интерфейса и, если нужно, чинит состояние сессии.
    private func describe(_ error: Error) async -> String {
        if let error = error as? QGramError, error.isUnauthorized {
            await session?.handleUnauthorized()
            return "Сессия истекла, войдите заново"
        }
        if let error = error as? QGramError, error.isMailboxMissing {
            await session?.loadAccount()
            return "Ящик ещё не создан"
        }
        return error.localizedDescription
    }

    func flash(_ text: String) {
        toastTask?.cancel()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) { toast = text }
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_900_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) { self?.toast = nil }
        }
    }
}
