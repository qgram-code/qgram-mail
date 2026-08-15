import Foundation

// MARK: - Папки

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
        all.first { $0.id == id }?.label ?? id
    }

    static func symbol(for id: String) -> String {
        all.first { $0.id == id }?.symbol ?? "tray"
    }
}

/// Счётчики папки из `GET /api/mail/folders`.
struct FolderCount: Equatable {
    var total: Int
    var unseen: Int

    static let zero = FolderCount(total: 0, unseen: 0)
}

// MARK: - Пользователь и ящик

struct QGramUser: Codable, Equatable {
    let id: Int?
    let username: String?
    let name: String?
    let email: String?
    let avatarUrl: String?

    var displayName: String {
        if let username, !username.isEmpty { return username }
        if let name, !name.isEmpty { return name.hasPrefix("@") ? String(name.dropFirst()) : name }
        return "аккаунт QGram"
    }
}

/// Состояние почтового ящика (`GET /api/mail/account`).
struct MailAccount: Codable, Equatable {
    var exists: Bool
    var address: String?
    var domain: String?
    var state: String?
    var active: Bool?
    var sendAllowed: Bool?
    var disabledReason: String?
    var sentToday: Int?
    var dailyLimit: Int?
    var canCreate: Bool?
    var reason: String?
    var suggestedLocalPart: String?

    var sendingBlocked: Bool { exists && sendAllowed == false }
    var moderationBlocked: Bool { state == "blocked" }
    var quotaSent: Int { sentToday ?? 0 }
    var quotaLimit: Int { dailyLimit ?? 50 }
    var mailDomain: String { domain ?? MailConfig.domain }
}

/// Домен и хосты почты — один источник правды для всего приложения.
enum MailConfig {
    static let domain = "qgram.fun"
    static let host = "mail.qgram.fun"
    static let imapPort = 993
    static let smtpPort = 465
    static let smtpStartTLSPort = 587
}

// MARK: - Письма

struct MailAttachment: Identifiable, Hashable {
    let id = UUID()
    let filename: String
    let contentType: String
    let size: Int

    /// «PDF», «PNG» — подпись на плитке вложения.
    var ext: String {
        let suffix = (filename as NSString).pathExtension.uppercased()
        if !suffix.isEmpty { return String(suffix.prefix(4)) }
        let sub = contentType.split(separator: "/").last.map(String.init) ?? "FILE"
        return String(sub.uppercased().prefix(4))
    }

    var meta: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB]
        return formatter.string(fromByteCount: Int64(max(size, 0)))
    }
}

/// Строка списка писем (`GET /api/mail/messages`).
struct MailMessage: Identifiable, Hashable {
    let num: String
    var folder: String
    var seen: Bool
    var flagged: Bool
    let fromName: String
    let fromAddress: String
    let to: String
    let subject: String
    let date: Date?
    let rawDate: String

    var id: String { "\(folder)/\(num)" }

    var displayName: String { fromName.isEmpty ? fromAddress : fromName }
    var displaySubject: String { subject.isEmpty ? "(без темы)" : subject }
    var time: String { MailDate.short(date) }
}

/// Открытое письмо (`GET /api/mail/messages/<folder>/<num>`).
struct MailMessageDetail: Identifiable, Equatable {
    let num: String
    let folder: String
    let fromName: String
    let fromAddress: String
    let to: String
    let cc: String
    let subject: String
    let date: Date?
    let rawDate: String
    let messageId: String
    let body: String
    let attachments: [MailAttachment]
    let spamFlag: Bool
    let authResults: String

    var id: String { "\(folder)/\(num)" }
    var displayName: String { fromName.isEmpty ? fromAddress : fromName }
    var displaySubject: String { subject.isEmpty ? "(без темы)" : subject }
    var time: String { MailDate.full(date, fallback: rawDate) }

    /// Метки DKIM / SPF / DMARC — вытаскиваются из строки Authentication-Results.
    var chips: [AuthChip] {
        let lowered = authResults.lowercased()
        return ["dkim", "spf", "dmarc"].compactMap { key in
            guard let range = lowered.range(of: "\(key)=") else { return nil }
            let rest = lowered[range.upperBound...].prefix { $0.isLetter }
            guard rest == "pass" else { return nil }
            return AuthChip(label: "\(key.uppercased()) пройдена")
        }
    }
}

/// Метка проверки подлинности письма.
struct AuthChip: Identifiable, Hashable {
    let id = UUID()
    let label: String
}

struct MailDraft: Equatable {
    var to: String = ""
    var cc: String = ""
    var subject: String = ""
    var body: String = ""
    var inReplyTo: String?
}

// MARK: - Экраны

enum Screen: String, Hashable {
    case list, message, folders, search, settings, blocked
}

enum SearchScope: String, Hashable, CaseIterable {
    case all, folder, unread
}

// MARK: - Даты

/// Разбор дат писем (RFC 5322) и их показ в интерфейсе.
enum MailDate {
    private static let parsers: [DateFormatter] = ["EEE, d MMM yyyy HH:mm:ss Z", "d MMM yyyy HH:mm:ss Z"].map {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = $0
        return formatter
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM"
        return formatter
    }()

    private static let fullFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM yyyy, HH:mm"
        return formatter
    }()

    static func parse(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // Хвост вида «(MSK)» ломает разбор.
        let cleaned = trimmed.replacingOccurrences(
            of: #"\s*\([^)]*\)\s*$"#, with: "", options: .regularExpression
        )
        for parser in parsers {
            if let date = parser.date(from: cleaned) { return date }
        }
        return ISO8601DateFormatter().date(from: cleaned)
    }

    static func short(_ date: Date?) -> String {
        guard let date else { return "" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return timeFormatter.string(from: date) }
        if calendar.isDateInYesterday(date) { return "вчера" }
        return dayFormatter.string(from: date)
    }

    static func full(_ date: Date?, fallback: String) -> String {
        guard let date else { return fallback }
        return fullFormatter.string(from: date)
    }
}
