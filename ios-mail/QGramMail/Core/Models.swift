import Foundation

struct MailFolder: Identifiable, Hashable {
    let id: String
    let label: String
    let symbol: String

    static let all: [MailFolder] = [
        MailFolder(id: "INBOX", label: "Входящие", symbol: "tray"),
        MailFolder(id: "Sent", label: "Отправленные", symbol: "paperplane"),
        MailFolder(id: "Drafts", label: "Черновики", symbol: "square.and.pencil"),
        MailFolder(id: "Junk", label: "Спам", symbol: "exclamationmark.triangle"),
        MailFolder(id: "Archive", label: "Архив", symbol: "archivebox"),
        MailFolder(id: "Trash", label: "Корзина", symbol: "trash")
    ]

    static func label(for id: String) -> String {
        all.first { $0.id == id }?.label ?? all[0].label
    }
}

struct MailAttachment: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let ext: String
    let meta: String
}

struct ThreadEntry: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let to: String
    let time: String
    let body: String
}

/// Результаты проверки подлинности письма (DKIM / SPF / DMARC).
struct AuthChip: Identifiable, Hashable {
    let id = UUID()
    let label: String
}

struct Message: Identifiable, Hashable {
    let id: Int
    var folder: String
    let name: String
    let address: String
    let subject: String
    let preview: String
    let time: String
    var seen: Bool
    var flagged: Bool
    let attachments: [MailAttachment]
    let chips: [AuthChip]
    let thread: [ThreadEntry]
}

struct MailDraft: Equatable {
    var to: String = ""
    var cc: String = ""
    var subject: String = ""
    var body: String = ""
}

enum Screen: String, Hashable {
    case list, message, folders, search, settings, blocked
}

enum SearchScope: String, Hashable, CaseIterable {
    case all, folder, unread
}
