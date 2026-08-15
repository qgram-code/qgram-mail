import SwiftUI
import UIKit

/// Поля на экранах входа и создания ящика (для программного переноса фокуса).
enum AuthFieldID: Hashable {
    case username, password, code, localPart
}

/// Вход через аккаунт QGram (`POST /api/login`, при 2FA — `/api/login/2fa`).
/// Почта привязана к аккаунту, поэтому другого способа войти нет.
@MainActor
struct LoginView: View {
    @EnvironmentObject private var session: Session
    @EnvironmentObject private var settings: SettingsStore

    @State private var username = ""
    @State private var password = ""
    @State private var code = ""
    @State private var challenge: String?
    @State private var busy = false
    @State private var error: String?
    @FocusState private var focus: AuthFieldID?

    private var accent: AccentTheme { settings.accent }

    var body: some View {
        ZStack {
            QM.bg.ignoresSafeArea()
            RadialGradient(
                colors: [accent.base.opacity(0.20), .clear],
                center: UnitPoint(x: 0.5, y: 0.14),
                startRadius: 0,
                endRadius: 520
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    AuthBadge(symbol: challenge == nil ? "envelope" : "lock.shield", accent: accent)

                    Text(challenge == nil ? "Почта QGram" : "Код подтверждения")
                        .font(.system(size: 30, weight: .semibold))
                        .tracking(-0.75)
                        .foregroundStyle(QM.text)
                        .padding(.top, 18)

                    Text(challenge == nil
                         ? "Войдите аккаунтом QGram — ящик на @\(MailConfig.domain) привязан к нему."
                         : "Код отправлен на почту, привязанную к аккаунту QGram. Он действует 10 минут.")
                        .font(.system(size: 15))
                        .lineSpacing(4)
                        .foregroundStyle(QM.secondary)
                        .padding(.top, 8)

                    if challenge == nil { credentials } else { twoFactor }

                    if let error {
                        Text(error)
                            .font(.system(size: 13))
                            .lineSpacing(3)
                            .foregroundStyle(QM.danger)
                            .padding(.top, 12)
                    }

                    AuthButton(
                        title: challenge == nil ? "Войти" : "Подтвердить",
                        busy: busy,
                        accent: accent,
                        action: submit
                    )
                    .padding(.top, 20)

                    if challenge != nil {
                        Button("Войти другим аккаунтом") {
                            challenge = nil
                            code = ""
                            error = nil
                        }
                        .font(.system(size: 14))
                        .foregroundStyle(QM.secondary)
                        .padding(.top, 14)
                        .frame(maxWidth: .infinity)
                    }

                    Text("Приложение обращается только к qgram.fun. Токен доступа хранится в Keychain устройства.")
                        .font(.system(size: 12))
                        .lineSpacing(3)
                        .foregroundStyle(QM.faint)
                        .padding(.top, 26)
                }
                .padding(.horizontal, 22)
                .padding(.top, 46)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    // MARK: - Поля

    private var credentials: some View {
        VStack(spacing: 10) {
            AuthField(
                placeholder: "Имя пользователя",
                text: $username,
                symbol: "person",
                id: .username,
                focus: $focus,
                contentType: .username,
                submitLabel: .next
            ) { focus = .password }

            AuthField(
                placeholder: "Пароль",
                text: $password,
                symbol: "key",
                id: .password,
                focus: $focus,
                secure: true,
                contentType: .password,
                submitLabel: .go
            ) { submit() }
        }
        .padding(.top, 24)
    }

    private var twoFactor: some View {
        AuthField(
            placeholder: "123456",
            text: $code,
            symbol: "number",
            id: .code,
            focus: $focus,
            contentType: .oneTimeCode,
            keyboard: .numberPad,
            submitLabel: .go
        ) { submit() }
            .padding(.top, 24)
    }

    // MARK: - Действия

    private func submit() {
        guard !busy else { return }
        error = nil
        focus = nil

        if let challenge {
            let value = code.trimmingCharacters(in: .whitespaces)
            guard value.count >= 4 else {
                error = "Введите код из письма"
                return
            }
            run { try await session.confirmTwoFactor(challenge: challenge, code: value) }
            return
        }

        let login = username.trimmingCharacters(in: .whitespaces)
        guard !login.isEmpty, !password.isEmpty else {
            error = "Введите логин и пароль"
            return
        }
        run {
            let outcome = try await session.login(username: login, password: password)
            if case let .twoFactor(challenge, _) = outcome {
                self.challenge = challenge
                self.password = ""
                self.focus = .code
            }
        }
    }

    private func run(_ work: @escaping () async throws -> Void) {
        busy = true
        Task {
            defer { busy = false }
            do {
                try await work()
                Haptics.success()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

// MARK: - Общие элементы экранов входа и онбординга

@MainActor
struct AuthBadge: View {
    let symbol: String
    let accent: AccentTheme

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 26, weight: .light))
            .foregroundStyle(accent.base)
            .frame(width: 60, height: 60)
            .background(accent.soft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(accent.base.opacity(0.3), lineWidth: 1)
            )
    }
}

@MainActor
struct AuthField: View {
    let placeholder: String
    @Binding var text: String
    let symbol: String
    let id: AuthFieldID
    @FocusState.Binding var focus: AuthFieldID?
    var secure = false
    var contentType: UITextContentType?
    var keyboard: UIKeyboardType = .default
    var submitLabel: SubmitLabel = .done
    var onSubmit: () -> Void = {}

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(QM.tertiary)
                .frame(width: 20)
            Group {
                if secure {
                    SecureField("", text: $text, prompt: Text(placeholder).foregroundColor(QM.tertiary))
                } else {
                    TextField("", text: $text, prompt: Text(placeholder).foregroundColor(QM.tertiary))
                }
            }
            .font(.system(size: 16.5))
            .foregroundStyle(QM.title)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textContentType(contentType)
            .keyboardType(keyboard)
            .submitLabel(submitLabel)
            .focused($focus, equals: id)
            .onSubmit(onSubmit)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(QM.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(QM.border, lineWidth: 1)
        )
    }
}

@MainActor
struct AuthButton: View {
    let title: String
    var busy = false
    let accent: AccentTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(.system(size: 16.5, weight: .medium))
                    .opacity(busy ? 0 : 1)
                if busy {
                    ProgressView().tint(accent.tint)
                }
            }
            .foregroundStyle(accent.tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(accent.soft, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(accent.base, lineWidth: 1)
            )
        }
        .buttonStyle(TapScaleStyle(scale: 0.98))
        .disabled(busy)
    }
}
