import SwiftUI
import UIKit

/// Создание ящика на @qgram.fun через `POST /api/mail/setup`.
/// Показывается один раз — пока `GET /api/mail/account` отвечает `exists: false`.
@MainActor
struct OnboardingView: View {
    @EnvironmentObject private var session: Session
    @EnvironmentObject private var settings: SettingsStore
    @FocusState private var focus: AuthFieldID?

    @State private var localPart = ""
    @State private var busy = false
    @State private var error: String?

    private var accent: AccentTheme { settings.accent }
    private var account: MailAccount? { session.account }
    private var domain: String { account?.mailDomain ?? MailConfig.domain }
    private var canCreate: Bool { account?.canCreate ?? true }

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
                Group {
                    if session.issuedAppPassword != nil { createdStep } else { newStep }
                }
                .padding(.horizontal, 22)
                .padding(.top, 44)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            if localPart.isEmpty {
                localPart = account?.suggestedLocalPart ?? session.user?.username ?? ""
            }
        }
    }

    // MARK: - Шаг 1: выбор адреса

    private var newStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            AuthBadge(symbol: "tray", accent: accent)

            Text("Почта QGram")
                .font(.system(size: 30, weight: .semibold))
                .tracking(-0.75)
                .foregroundStyle(QM.text)
                .padding(.top, 18)

            Text("Свой адрес на домене \(domain). Выберите имя ящика — изменить его позже нельзя.")
                .font(.system(size: 15))
                .lineSpacing(4)
                .foregroundStyle(QM.secondary)
                .padding(.top, 8)

            HStack(spacing: 8) {
                TextField("", text: $localPart, prompt: Text("имя").foregroundColor(QM.tertiary))
                    .font(.system(size: 17))
                    .foregroundStyle(QM.title)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .focused($focus, equals: .localPart)
                    .onSubmit(create)
                    .padding(.vertical, 13)
                Text("@\(domain)")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundStyle(QM.tertiary)
            }
            .padding(.leading, 14)
            .padding(.trailing, 12)
            .background(QM.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(QM.border, lineWidth: 1)
            )
            .padding(.top, 24)
            .disabled(!canCreate)

            Text("Латиница, цифры, точка, дефис, подчёркивание.")
                .font(.system(size: 12.5))
                .foregroundStyle(QM.tertiary)
                .padding(.top, 10)

            if let text = blockingReason {
                noticeCard(text)
                    .padding(.top, 16)
            }

            if let error {
                Text(error)
                    .font(.system(size: 13))
                    .lineSpacing(3)
                    .foregroundStyle(QM.danger)
                    .padding(.top, 14)
            }

            Text("""
            Ящик рассчитан на личную переписку. Действуют лимиты на число писем \
            в час и в сутки — это защищает домен \(domain) от попадания в спам-списки. \
            Массовые рассылки запрещены.
            """)
                .font(.system(size: 12))
                .lineSpacing(3)
                .foregroundStyle(QM.faint)
                .padding(.top, 22)

            AuthButton(title: "Создать ящик", busy: busy, accent: accent, action: create)
                .padding(.top, 18)
                .disabled(!canCreate)
                .opacity(canCreate ? 1 : 0.5)

            Button("Выйти из аккаунта QGram") {
                Task { await session.signOut() }
            }
            .font(.system(size: 14))
            .foregroundStyle(QM.secondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 16)
        }
    }

    private var blockingReason: String? {
        if let error = session.accountError { return error }
        guard !canCreate else { return nil }
        let reason = account?.reason ?? ""
        return reason.isEmpty
            ? "Создание ящика для этого аккаунта пока недоступно."
            : reason
    }

    // MARK: - Шаг 2: ящик создан

    private var createdStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            AuthBadge(symbol: "checkmark.shield", accent: accent)

            Text("Ящик создан")
                .font(.system(size: 27, weight: .semibold))
                .tracking(-0.68)
                .foregroundStyle(QM.text)
                .padding(.top, 18)

            Text("Ваш адрес:")
                .font(.system(size: 14.5))
                .foregroundStyle(QM.secondary)
                .padding(.top, 8)

            MonoBox(text: session.address, color: QM.text)
                .padding(.top, 8)

            (
                Text("Пароль для почтовых клиентов (IMAP/SMTP). Он показывается ")
                    .foregroundColor(QM.secondary)
                + Text("только один раз").foregroundColor(QM.text).bold()
                + Text(" — сохраните его сейчас. В самом приложении он не нужен.")
                    .foregroundColor(QM.secondary)
            )
            .font(.system(size: 13.5))
            .lineSpacing(3)
            .padding(.top, 18)

            MonoBox(text: session.issuedAppPassword ?? "", color: accent.tint)
                .padding(.top, 8)
                .textSelection(.enabled)

            Button {
                UIPasteboard.general.string = session.issuedAppPassword
                Haptics.success()
            } label: {
                Label("Скопировать пароль", systemImage: "doc.on.doc")
                    .font(.system(size: 14))
                    .foregroundStyle(accent.base)
            }
            .buttonStyle(TapScaleStyle(scale: 0.96))
            .padding(.top, 12)

            AuthButton(title: "Открыть почту", accent: accent) {
                Haptics.tap()
                session.enterMail()
            }
            .padding(.top, 26)
        }
    }

    // MARK: - Действия

    private func create() {
        guard !busy, canCreate else { return }
        let cleaned = sanitize(localPart)
        guard !cleaned.isEmpty else {
            error = "Введите имя ящика"
            return
        }
        focus = nil
        error = nil
        busy = true
        Task {
            defer { busy = false }
            do {
                try await session.createMailbox(localPart: cleaned)
                Haptics.success()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func sanitize(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        let scalars = value.lowercased().unicodeScalars.filter { allowed.contains($0) && $0.isASCII }
        return String(String.UnicodeScalarView(scalars))
    }

    private func noticeCard(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 14))
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 12.5))
                .lineSpacing(3)
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
}

/// Моноширинная плашка для адреса и пароля.
@MainActor
struct MonoBox: View {
    let text: String
    var color: Color = QM.text

    var body: some View {
        Text(text)
            .font(.system(size: 14, design: .monospaced))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(QM.card, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(QM.border, lineWidth: 1)
            )
    }
}
