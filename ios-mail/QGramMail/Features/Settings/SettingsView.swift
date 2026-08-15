import SwiftUI
import UIKit

@MainActor
struct SettingsView: View {
    @EnvironmentObject private var store: MailStore
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var session: Session

    @State private var resetting = false
    @State private var confirmReset = false
    @State private var confirmSignOut = false

    private var accent: AccentTheme { settings.accent }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    accountSection
                    mailboxSection
                    styleSection
                    behaviourSection
                    clientSection
                    signOutButton
                }
                .padding(.horizontal, 14)
                .padding(.top, 16)
                .padding(.bottom, 140)
            }
            .refreshable { await session.loadAccount() }
        }
        .background(QM.bg)
        .sheet(item: passwordBinding) { password in
            AppPasswordSheet(password: password.value, accent: accent)
                .presentationDetents([.medium])
                .preferredColorScheme(.dark)
        }
        .confirmationDialog(
            "Выпустить новый пароль почты?",
            isPresented: $confirmReset,
            titleVisibility: .visible
        ) {
            Button("Выпустить новый", role: .destructive) { resetPassword() }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Старый пароль перестанет работать сразу — почтовые клиенты придётся настроить заново.")
        }
        .confirmationDialog("Выйти из аккаунта?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Выйти", role: .destructive) { Task { await session.signOut() } }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Письма останутся на сервере — приложение просто забудет токен доступа.")
        }
    }

    private var header: some View {
        LargeTitle(text: "Настройки")
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
            .overlay(alignment: .bottom) { HairLine() }
    }

    // MARK: - Аккаунт QGram

    private var accountSection: some View {
        section("Аккаунт QGram") {
            HStack(spacing: 12) {
                Avatar(name: session.user?.displayName ?? "Q", size: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.user?.displayName ?? "Аккаунт QGram")
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(QM.text)
                    if let email = session.user?.email, !email.isEmpty {
                        Text(email)
                            .font(.system(size: 12.5))
                            .foregroundStyle(QM.tertiary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)

            HairLine()

            Text("Вход в почту выполняется аккаунтом qgram.fun. Токен доступа хранится в Keychain устройства и не покидает его.")
                .font(.system(size: 12.5))
                .lineSpacing(3)
                .foregroundStyle(QM.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
        }
    }

    // MARK: - Ящик

    private var mailboxSection: some View {
        section("Ящик") {
            HStack {
                Text("Адрес").font(.system(size: 15.5)).foregroundStyle(QM.text)
                Spacer(minLength: 12)
                Text(session.address)
                    .font(.system(size: 13.5, design: .monospaced))
                    .foregroundStyle(QM.secondary)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)

            HairLine()

            HStack {
                Text("Состояние").font(.system(size: 15.5)).foregroundStyle(QM.text)
                Spacer(minLength: 12)
                Text(stateText)
                    .font(.system(size: 13.5))
                    .foregroundStyle(session.sendingBlocked ? QM.warnText : QM.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)

            HairLine()

            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("Лимит отправки").font(.system(size: 15.5)).foregroundStyle(QM.text)
                    Spacer()
                    Text("\(session.sentToday) из \(session.dailyLimit)")
                        .font(.system(size: 13.5))
                        .monospacedDigit()
                        .foregroundStyle(QM.secondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(QM.track)
                        Capsule()
                            .fill(accent.base)
                            .frame(width: geo.size.width * quotaFraction)
                    }
                }
                .frame(height: 4)
                Text("Действует также почасовой лимит. Он нужен, чтобы домен \(session.domain) не попал в спам-списки.")
                    .font(.system(size: 12.5))
                    .lineSpacing(3)
                    .foregroundStyle(QM.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
        }
    }

    private var quotaFraction: Double {
        guard session.dailyLimit > 0 else { return 0 }
        return min(Double(session.sentToday) / Double(session.dailyLimit), 1)
    }

    private var stateText: String {
        switch session.account?.state {
        case "blocked": return "Заблокирован"
        case "nosend": return "Только приём"
        default: return "Активен"
        }
    }

    // MARK: - Стиль (акцентный цвет)

    private var styleSection: some View {
        section("Стиль") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Акцентный цвет").font(.system(size: 15.5)).foregroundStyle(QM.text)
                    Spacer()
                    Text(currentAccentName)
                        .font(.system(size: 13.5))
                        .foregroundStyle(QM.secondary)
                }

                HStack(spacing: 12) {
                    ForEach(AccentOption.all) { option in
                        Button {
                            Haptics.tap()
                            withAnimation(.easeOut(duration: 0.2)) { settings.accentHex = option.hex }
                        } label: {
                            Circle()
                                .fill(Color(hex: option.hex))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .strokeBorder(QM.text, lineWidth: 2)
                                        .padding(-4)
                                        .opacity(settings.accentHex == option.hex ? 1 : 0)
                                )
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(QM.bg)
                                        .opacity(settings.accentHex == option.hex ? 1 : 0)
                                )
                                .accessibilityLabel(option.name)
                        }
                        .buttonStyle(TapScaleStyle(scale: 0.88))
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 4)

                Text("Цвет применяется сразу: кнопки, метки непрочитанного, полоса квоты и активная вкладка.")
                    .font(.system(size: 12.5))
                    .lineSpacing(3)
                    .foregroundStyle(QM.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
        }
    }

    private var currentAccentName: String {
        AccentOption.all.first { $0.hex == settings.accentHex }?.name ?? "Свой"
    }

    // MARK: - Поведение

    private var behaviourSection: some View {
        section("Поведение") {
            ToggleRow(
                title: "Показывать квоту на главном экране",
                caption: "Плашка «Отправлено сегодня» над списком писем",
                isOn: $settings.showQuota,
                accent: accent
            )
            HairLine()
            ToggleRow(title: "Свайпы по письму", isOn: $settings.swipesEnabled, accent: accent)
            HairLine()
            ToggleRow(
                title: "Текст письма в списке",
                caption: "Подтягивает первые строки письма — чуть больше запросов к серверу",
                isOn: $settings.showPreviews,
                accent: accent
            )
            HairLine()
            ToggleRow(title: "Показывать превью на экране блокировки", isOn: $settings.lockScreenPreview, accent: accent)
        }
    }

    // MARK: - Настройка почтового клиента

    private var clientSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionCaption(text: "Настройка почтового клиента")
                .padding(.horizontal, 4)

            Text("""
            IMAP: \(MailConfig.host), порт \(MailConfig.imapPort), SSL/TLS
            SMTP: \(MailConfig.host), порт \(MailConfig.smtpPort), SSL/TLS
                   (или порт \(MailConfig.smtpStartTLSPort) с STARTTLS)
            Логин: \(session.address)
            Пароль: отдельный пароль приложения
            """)
            .font(.system(size: 12.5, design: .monospaced))
            .lineSpacing(7)
            .foregroundStyle(Color(hex: "B2B6CA"))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .qmCard()

            Button {
                confirmReset = true
            } label: {
                ZStack {
                    Text("Сбросить пароль почты")
                        .font(.system(size: 15.5, weight: .medium))
                        .opacity(resetting ? 0 : 1)
                    if resetting { ProgressView().tint(accent.tint) }
                }
                .foregroundStyle(accent.tint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(accent.softer, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(accent.line, lineWidth: 1)
                )
            }
            .buttonStyle(TapScaleStyle(scale: 0.98))
            .disabled(resetting)
            .padding(.top, 2)

            Text("Пароль хранится только в виде хеша, поэтому посмотреть текущий нельзя — можно лишь выпустить новый (`POST /api/mail/password`).")
                .font(.system(size: 12))
                .lineSpacing(3)
                .foregroundStyle(QM.tertiary)
                .padding(.horizontal, 4)
        }
    }

    private var signOutButton: some View {
        Button {
            confirmSignOut = true
        } label: {
            Text("Выйти из аккаунта")
                .font(.system(size: 15.5, weight: .medium))
                .foregroundStyle(QM.danger)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(QM.danger.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(QM.danger.opacity(0.4), lineWidth: 1)
                )
        }
        .buttonStyle(TapScaleStyle(scale: 0.98))
    }

    // MARK: - Действия

    private var passwordBinding: Binding<IdentifiedString?> {
        Binding(
            get: { session.issuedAppPassword.map(IdentifiedString.init) },
            set: { if $0 == nil { session.issuedAppPassword = nil } }
        )
    }

    private func resetPassword() {
        guard !resetting else { return }
        resetting = true
        Task {
            defer { resetting = false }
            do {
                try await session.resetAppPassword()
                Haptics.success()
            } catch {
                store.flash(error.localizedDescription)
            }
        }
    }

    // MARK: - Обёртка секции

    private func section<Content: View>(_ caption: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionCaption(text: caption)
                .padding(.horizontal, 4)
            VStack(spacing: 0) { content() }
                .qmCard()
        }
    }
}

/// Обёртка для `sheet(item:)` — строка сама по себе не `Identifiable`.
struct IdentifiedString: Identifiable {
    let value: String
    var id: String { value }

    init(_ value: String) { self.value = value }
}

/// Шторка с новым паролем приложения — сервер показывает его один раз.
@MainActor
struct AppPasswordSheet: View {
    let password: String
    let accent: AccentTheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(QM.fill)
                .frame(width: 38, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 18)

            Text("Новый пароль почты")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(QM.text)

            Text("Показывается один раз. Старый пароль уже не работает — обновите его в почтовых клиентах.")
                .font(.system(size: 13.5))
                .lineSpacing(3)
                .foregroundStyle(QM.secondary)
                .padding(.top, 8)

            MonoBox(text: password, color: accent.tint)
                .textSelection(.enabled)
                .padding(.top, 14)

            Button {
                UIPasteboard.general.string = password
                Haptics.success()
            } label: {
                Label("Скопировать", systemImage: "doc.on.doc")
                    .font(.system(size: 14))
                    .foregroundStyle(accent.base)
            }
            .buttonStyle(TapScaleStyle(scale: 0.96))
            .padding(.top, 12)

            Spacer(minLength: 0)

            AuthButton(title: "Готово", accent: accent) { dismiss() }
                .padding(.bottom, 18)
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(QM.sheet)
    }
}
