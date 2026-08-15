import Foundation

/// Ошибки qgram API. Коды — из `API_USAGE.txt`, тексты уже готовы к показу.
enum QGramError: LocalizedError {
    case network(String)
    case decoding
    case api(status: Int, code: String, message: String?)
    case twoFactorRequired(challenge: String, expiresIn: Int)

    var code: String {
        if case let .api(_, code, _) = self { return code }
        return ""
    }

    var isUnauthorized: Bool {
        if case let .api(status, code, _) = self {
            return status == 401 || code == "unauthorized" || code == "auth_required"
        }
        return false
    }

    /// Ящик ещё не создан — это не ошибка, а состояние онбординга.
    var isMailboxMissing: Bool { code == "mailbox_missing" }

    var errorDescription: String? {
        switch self {
        case let .network(text):
            return text
        case .decoding:
            return "Не удалось разобрать ответ сервера"
        case .twoFactorRequired:
            return "Требуется код двухфакторной проверки"
        case let .api(status, code, message):
            if let text = QGramError.known[code] { return text }
            if let message, !message.isEmpty { return message }
            return "Ошибка сервера (\(status))"
        }
    }

    private static let known: [String: String] = [
        "invalid_credentials": "Неверный логин или пароль",
        "invalid_challenge": "Сессия входа устарела, попробуйте снова",
        "challenge_expired": "Срок кода истёк, войдите заново",
        "invalid_code": "Неверный код",
        "code_expired": "Код истёк, запросите новый",
        "rate_limited": "Слишком много попыток, попробуйте позже",
        "unauthorized": "Нужно войти в аккаунт QGram",
        "auth_required": "Нужно войти в аккаунт QGram",
        "account_banned": "Аккаунт заблокирован",
        "account_frozen": "Аккаунт заморожен",
        "verification_required": "Нужна верификация аккаунта QGram",
        "mailbox_missing": "Ящик ещё не создан",
        "mailbox_exists": "Ящик уже создан",
        "mailbox_blocked": "Ящик заблокирован модерацией",
        "mailbox_create_failed": "Адрес занят или недопустим",
        "sending_blocked": "Отправка отключена, приём писем работает",
        "mail_unavailable": "Почтовый сервер недоступен",
        "message_not_found": "Письмо не найдено",
        "not_allowed": "Создание ящика пока недоступно для этого аккаунта",
        "send_failed": "Письмо не отправлено"
    ]
}

// MARK: - Ответы API

struct LoginUserResponse: Decodable {
    let token: String?
    let user: QGramUser?
    let challengeToken: String?
    let expiresIn: Int?
}

struct MeResponse: Decodable {
    let user: QGramUser?
}

struct MailAccountResponse: Decodable {
    let account: MailAccount
    let folders: [MailFolderResponse]?
}

struct MailFolderResponse: Decodable {
    let name: String
    let title: String?
    let total: Int?
    let unseen: Int?
}

struct MailSetupResponse: Decodable {
    let address: String
    let appPassword: String
    let account: MailAccount?
}

struct MailPasswordResponse: Decodable {
    let address: String
    let appPassword: String
}

struct MailFoldersResponse: Decodable {
    let folders: [MailFolderResponse]
}

struct MailListResponse: Decodable {
    let folder: String
    let page: Int?
    let perPage: Int?
    let total: Int?
    let messages: [MailMessageResponse]
}

struct MailMessageResponse: Decodable {
    let num: FlexibleID
    let seen: Bool?
    let flagged: Bool?
    let from: String?
    let fromName: String?
    let to: String?
    let subject: String?
    let date: String?
}

struct MailDetailResponse: Decodable {
    let message: MailMessageBody
}

struct MailMessageBody: Decodable {
    let num: FlexibleID
    let from: String?
    let fromName: String?
    let fromAddr: String?
    let to: String?
    let cc: String?
    let subject: String?
    let date: String?
    let messageId: String?
    let body: String?
    let attachments: [MailAttachmentResponse]?
    let spamFlag: Bool?
    let authResults: String?
}

struct MailAttachmentResponse: Decodable {
    let filename: String?
    let contentType: String?
    let size: Int?
}

struct MailSendResponse: Decodable {
    let from: String?
    let to: [String]?
    let sentToday: Int?
    let dailyLimit: Int?
}

struct MailActionResponse: Decodable {
    let action: String?
    let movedTo: String?
}

/// Номер письма приходит строкой, но не будем зависеть от этого.
struct FlexibleID: Decodable, Hashable {
    let value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            value = text
        } else if let number = try? container.decode(Int.self) {
            value = String(number)
        } else {
            value = ""
        }
    }
}

// MARK: - Клиент

/// Результат `POST /api/login`.
enum LoginOutcome {
    case token(String, QGramUser?)
    case twoFactor(challenge: String, expiresIn: Int)
}

/// Тонкий клиент qgram API: bearer-токен, JSON, разбор ошибок.
actor QGramAPI {
    static let shared = QGramAPI()

    static let baseURL = URL(string: "https://qgram.fun")!

    private var token: String?

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        config.httpAdditionalHeaders = ["Accept": "application/json"]
        return URLSession(configuration: config)
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    func setToken(_ value: String?) { token = value }

    var isAuthorized: Bool { token?.isEmpty == false }

    // MARK: Аккаунт QGram

    func login(username: String, password: String) async throws -> LoginOutcome {
        do {
            let response: LoginUserResponse = try await send(
                "/api/login", method: "POST", body: ["username": username, "password": password]
            )
            guard let token = response.token else { throw QGramError.decoding }
            return .token(token, response.user)
        } catch QGramError.twoFactorRequired(let challenge, let expiresIn) {
            return .twoFactor(challenge: challenge, expiresIn: expiresIn)
        }
    }

    func confirmTwoFactor(challenge: String, code: String) async throws -> LoginOutcome {
        let response: LoginUserResponse = try await send(
            "/api/login/2fa", method: "POST", body: ["challenge_token": challenge, "code": code]
        )
        guard let token = response.token else { throw QGramError.decoding }
        return .token(token, response.user)
    }

    func me() async throws -> QGramUser? {
        let response: MeResponse = try await send("/api/me")
        return response.user
    }

    func logout() async {
        _ = try? await sendRaw("/api/logout", method: "POST", body: nil)
        token = nil
    }

    // MARK: Ящик

    func mailAccount() async throws -> MailAccountResponse {
        try await send("/api/mail/account")
    }

    func createMailbox(localPart: String?) async throws -> MailSetupResponse {
        var body: [String: Any] = [:]
        if let localPart, !localPart.isEmpty { body["local_part"] = localPart }
        return try await send("/api/mail/setup", method: "POST", body: body)
    }

    func resetMailPassword() async throws -> MailPasswordResponse {
        try await send("/api/mail/password", method: "POST", body: [:])
    }

    // MARK: Письма

    func folders() async throws -> [MailFolderResponse] {
        let response: MailFoldersResponse = try await send("/api/mail/folders")
        return response.folders
    }

    func messages(folder: String, page: Int, perPage: Int, query: String? = nil) async throws -> MailListResponse {
        var items = [
            URLQueryItem(name: "folder", value: folder),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(min(perPage, 50)))
        ]
        if let query, !query.isEmpty { items.append(URLQueryItem(name: "q", value: query)) }
        return try await send("/api/mail/messages", query: items)
    }

    func message(folder: String, num: String, peek: Bool = false) async throws -> MailMessageBody {
        let path = "/api/mail/messages/\(escape(folder))/\(escape(num))"
        let query = peek ? [URLQueryItem(name: "peek", value: "1")] : []
        let response: MailDetailResponse = try await send(path, query: query)
        return response.message
    }

    @discardableResult
    func perform(action: String, folder: String, num: String) async throws -> MailActionResponse {
        try await send(
            "/api/mail/messages/\(escape(folder))/\(escape(num))/action",
            method: "POST",
            body: ["action": action]
        )
    }

    func sendMail(
        to: [String], cc: [String], subject: String, body: String, inReplyTo: String?
    ) async throws -> MailSendResponse {
        var payload: [String: Any] = ["to": to, "subject": subject, "body": body]
        if !cc.isEmpty { payload["cc"] = cc }
        if let inReplyTo, !inReplyTo.isEmpty { payload["in_reply_to"] = inReplyTo }
        return try await send("/api/mail/send", method: "POST", body: payload)
    }

    // MARK: Транспорт

    private func escape(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }

    private func send<T: Decodable>(
        _ path: String, method: String = "GET", query: [URLQueryItem] = [], body: [String: Any]? = nil
    ) async throws -> T {
        let data = try await sendRaw(path, method: method, query: query, body: body)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw QGramError.decoding
        }
    }

    @discardableResult
    private func sendRaw(
        _ path: String, method: String = "GET", query: [URLQueryItem] = [], body: [String: Any]? = nil
    ) async throws -> Data {
        guard var components = URLComponents(
            url: QGramAPI.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false
        ) else {
            throw QGramError.network("Неверный адрес запроса")
        }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw QGramError.network("Неверный адрес запроса") }

        var request = URLRequest(url: url)
        request.httpMethod = method
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw QGramError.network(QGramAPI.text(for: error))
        } catch {
            throw QGramError.network(error.localizedDescription)
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let envelope = try? decoder.decode(Envelope.self, from: data)

        if let envelope, envelope.error == "2fa_required" {
            throw QGramError.twoFactorRequired(
                challenge: envelope.challengeToken ?? "", expiresIn: envelope.expiresIn ?? 600
            )
        }
        guard (200..<300).contains(status), envelope?.ok != false else {
            throw QGramError.api(
                status: status, code: envelope?.error ?? "", message: envelope?.message
            )
        }
        return data
    }

    private struct Envelope: Decodable {
        let ok: Bool?
        let error: String?
        let message: String?
        let challengeToken: String?
        let expiresIn: Int?
    }

    private static func text(for error: URLError) -> String {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return "Нет соединения с интернетом"
        case .timedOut:
            return "Сервер qgram.fun не отвечает"
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return "Не удалось подключиться к qgram.fun"
        default:
            return error.localizedDescription
        }
    }
}
