import SwiftUI

/// Вход через qgram и состояние почтового ящика.
/// Почта привязана к аккаунту qgram: отдельного логина в неё нет,
/// всё API работает по bearer-токену из `POST /api/login`.
@MainActor
final class Session: ObservableObject {
    enum Stage: Equatable {
        /// Проверяем сохранённый токен.
        case launching
        /// Нужен вход в аккаунт qgram.
        case login
        /// Аккаунт есть, ящика ещё нет — онбординг создания.
        case mailbox
        /// Всё готово, показываем почту.
        case ready
    }

    @Published private(set) var stage: Stage = .launching
    @Published private(set) var user: QGramUser?
    @Published private(set) var account: MailAccount?
    @Published private(set) var accountError: String?
    /// Пароль приложения для IMAP/SMTP — сервер отдаёт его ровно один раз.
    @Published var issuedAppPassword: String?

    private let api = QGramAPI.shared

    // MARK: - Производные значения

    var address: String { account?.address ?? "" }
    var domain: String { account?.mailDomain ?? MailConfig.domain }
    var sentToday: Int { account?.quotaSent ?? 0 }
    var dailyLimit: Int { account?.quotaLimit ?? 50 }
    var sendingBlocked: Bool { account?.sendingBlocked ?? false }
    var blockReason: String? { account?.disabledReason }

    // MARK: - Запуск

    func restore() async {
        guard let token = TokenStore.load() else {
            stage = .login
            return
        }
        await api.setToken(token)
        do {
            user = try await api.me()
        } catch let error as QGramError where error.isUnauthorized {
            await signOutLocally()
            return
        } catch {
            // Профиль не критичен: если сеть отвалилась, покажем ошибку на почте.
        }
        await loadAccount()
    }

    // MARK: - Вход

    func login(username: String, password: String) async throws -> LoginOutcome {
        let outcome = try await api.login(username: username, password: password)
        if case let .token(token, user) = outcome {
            try await finishLogin(token: token, user: user)
        }
        return outcome
    }

    func confirmTwoFactor(challenge: String, code: String) async throws {
        let outcome = try await api.confirmTwoFactor(challenge: challenge, code: code)
        if case let .token(token, user) = outcome {
            try await finishLogin(token: token, user: user)
        }
    }

    private func finishLogin(token: String, user: QGramUser?) async throws {
        TokenStore.save(token)
        await api.setToken(token)
        if let user {
            self.user = user
        } else {
            self.user = try? await api.me()
        }
        await loadAccount()
    }

    func signOut() async {
        await api.logout()
        await signOutLocally()
    }

    private func signOutLocally() async {
        TokenStore.clear()
        await api.setToken(nil)
        user = nil
        account = nil
        accountError = nil
        issuedAppPassword = nil
        stage = .login
    }

    /// Токен протух посреди работы — возвращаемся на экран входа.
    func handleUnauthorized() async {
        await signOutLocally()
    }

    // MARK: - Ящик

    func loadAccount() async {
        do {
            let response = try await api.mailAccount()
            apply(response.account)
            accountError = nil
        } catch let error as QGramError where error.isUnauthorized {
            await signOutLocally()
        } catch let error as QGramError where error.isMailboxMissing {
            account = MailAccount(
                exists: false, address: nil, domain: MailConfig.domain, state: nil, active: nil,
                sendAllowed: nil, disabledReason: nil, sentToday: nil, dailyLimit: nil,
                canCreate: true, reason: nil, suggestedLocalPart: user?.username
            )
            accountError = nil
            stage = .mailbox
        } catch {
            accountError = error.localizedDescription
            // Без состояния ящика показывать почту нечего — остаёмся на онбординге,
            // если раньше ящика не было, иначе продолжаем работать с тем, что есть.
            if account?.exists != true { stage = .mailbox }
        }
    }

    func createMailbox(localPart: String) async throws {
        let response = try await api.createMailbox(localPart: localPart)
        issuedAppPassword = response.appPassword
        if let account = response.account {
            apply(account)
        } else {
            await loadAccount()
        }
    }

    func resetAppPassword() async throws {
        let response = try await api.resetMailPassword()
        issuedAppPassword = response.appPassword
    }

    /// Обновить квоту после отправки письма, не дёргая весь экран.
    func applyQuota(sent: Int?, limit: Int?) {
        guard var account else { return }
        if let sent { account.sentToday = sent }
        if let limit { account.dailyLimit = limit }
        self.account = account
    }

    func enterMail() {
        issuedAppPassword = nil
        stage = account?.exists == true ? .ready : .mailbox
    }

    private func apply(_ account: MailAccount) {
        self.account = account
        if account.exists {
            // Пока показываем выданный пароль, не уводим пользователя с онбординга.
            if issuedAppPassword == nil { stage = .ready }
        } else {
            stage = .mailbox
        }
    }
}
