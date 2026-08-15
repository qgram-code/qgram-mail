import SwiftUI

/// Состояние почты: письма, текущий экран, черновик, тосты.
/// Данные пока демонстрационные (SeedData) — сетевой слой подключается сюда же.
@MainActor
final class MailStore: ObservableObject {
    @Published var messages: [Message] = SeedData.messages
    @Published var folder: String = "INBOX"
    @Published var screen: Screen = .list
    @Published var openID: Int?
    @Published var expanded: Set<Int> = []

    @Published var composeOpen = false
    @Published var attachmentsOpen = false
    @Published var draft = MailDraft()

    @Published var query = ""
    @Published var scope: SearchScope = .all

    @Published var sentToday = 12
    @Published var toast: String?

    private var toastTask: Task<Void, Never>?

    // MARK: - Выборки

    var currentFolderMessages: [Message] {
        messages.filter { $0.folder == folder }
    }

    var unseenInbox: Int {
        messages.filter { $0.folder == "INBOX" && !$0.seen }.count
    }

    var folderLabel: String { MailFolder.label(for: folder) }

    var folderCountLabel: String {
        let count = currentFolderMessages.count
        return count > 0 ? "\(count) писем" : ""
    }

    var openMessage: Message? {
        guard let openID else { return nil }
        return messages.first { $0.id == openID }
    }

    var showsTabBar: Bool {
        screen == .list || screen == .folders || screen == .settings
    }

    func unseenCount(in folderID: String) -> Int {
        messages.filter { $0.folder == folderID && !$0.seen }.count
    }

    func count(in folderID: String) -> Int {
        messages.filter { $0.folder == folderID }.count
    }

    func results(scopedTo folderID: String) -> [Message] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        return messages.filter { message in
            switch scope {
            case .all: break
            case .folder: if message.folder != folderID { return false }
            case .unread: if message.seen { return false }
            }
            return (message.name + message.subject + message.preview).lowercased().contains(q)
        }
    }

    // MARK: - Навигация

    func go(to screen: Screen) {
        withAnimation(.easeOut(duration: 0.18)) { self.screen = screen }
    }

    func openInbox() {
        openID = nil
        folder = "INBOX"
        go(to: .list)
    }

    func open(_ message: Message) {
        Haptics.tap()
        markSeen(message.id, seen: true)
        openID = message.id
        expanded = [message.thread.count - 1]
        go(to: .message)
    }

    func pick(folder id: String) {
        Haptics.tap()
        folder = id
        openID = nil
        go(to: .list)
    }

    func toggleExpanded(_ index: Int) {
        if expanded.contains(index) { expanded.remove(index) } else { expanded.insert(index) }
    }

    // MARK: - Действия над письмами

    func move(_ id: Int, to destination: String, toast text: String) {
        Haptics.tap()
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.easeInOut(duration: 0.22)) {
            messages[index].folder = destination
            messages[index].seen = true
            if openID == id {
                openID = nil
                screen = .list
            }
        }
        flash(text)
    }

    func markSeen(_ id: Int, seen: Bool) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].seen = seen
    }

    func toggleSeen(_ id: Int) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        Haptics.tap()
        messages[index].seen.toggle()
        flash(messages[index].seen ? "Помечено прочитанным" : "Помечено непрочитанным")
    }

    func markOpenUnread() {
        guard let id = openID else { return }
        Haptics.tap()
        markSeen(id, seen: false)
        openID = nil
        go(to: .list)
        flash("Помечено непрочитанным")
    }

    // MARK: - Написание письма

    func compose(to recipient: String = "", subject: String = "", body: String = "") {
        Haptics.tap()
        draft = MailDraft(to: recipient, cc: "", subject: subject, body: body)
        composeOpen = true
    }

    func composeNew(blocked: Bool) {
        guard !blocked else {
            flash("Отправка приостановлена модерацией")
            return
        }
        compose()
    }

    func send() {
        Haptics.success()
        composeOpen = false
        sentToday += 1
        flash("Письмо отправлено")
    }

    // MARK: - Обновление и тосты

    func refresh() async {
        try? await Task.sleep(nanoseconds: 1_300_000_000)
        flash("Новых писем нет")
    }

    func flash(_ text: String) {
        toastTask?.cancel()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) { toast = text }
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_900_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) { self?.toast = nil }
            }
        }
    }
}
