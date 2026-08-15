import SwiftUI

/// Первый запуск: выбор имени ящика и одноразовый пароль для IMAP/SMTP.
@MainActor
struct OnboardingView: View {
    @EnvironmentObject private var store: MailStore
    @EnvironmentObject private var settings: SettingsStore
    @FocusState private var focused: Bool

    @State private var created = false
    @State private var localPart = ""

    private var accent: AccentTheme { settings.accent }
    private let mailPassword = "k7Qz-4mХp-92Rd-Ls1v"

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

            Group {
                if created { createdStep } else { newStep }
            }
            .padding(.horizontal, 22)
            .padding(.top, 40)
            .padding(.bottom, 44)
        }
        .onAppear { localPart = settings.localPart }
    }

    // MARK: - Шаг 1: выбор адреса

    private var newStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            badge(symbol: "tray")

            Text("Почта QGram")
                .font(.system(size: 30, weight: .semibold))
                .tracking(-0.75)
                .foregroundStyle(QM.text)
                .padding(.top, 18)

            Text("Свой адрес на домене qgram.im. Выберите имя ящика — изменить его позже нельзя.")
                .font(.system(size: 15))
                .lineSpacing(4)
                .foregroundStyle(QM.secondary)
                .padding(.top, 8)

            HStack(spacing: 8) {
                TextField("", text: $localPart)
                    .font(.system(size: 17))
                    .foregroundStyle(QM.title)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .padding(.vertical, 13)
                Text("@qgram.im")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundStyle(QM.tertiary)
            }
            .padding(.leading, 14)
            .padding(.trailing, 12)
            .background(QM.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color(hex: "E9E9ED").opacity(0.10), lineWidth: 1)
            )
            .padding(.top, 24)

            Text("Латиница, цифры, точка, дефис, подчёркивание.")
                .font(.system(size: 12.5))
                .foregroundStyle(QM.tertiary)
                .padding(.top, 10)

            Spacer(minLength: 20)

            Text("Ящик рассчитан на личную переписку. Действуют лимиты на число писем в час и в сутки — это защищает домен qgram.im от попадания в спам-списки. Массовые рассылки запрещены.")
                .font(.system(size: 12))
                .lineSpacing(3)
                .foregroundStyle(QM.faint)
                .padding(.bottom, 14)

            primaryButton("Создать ящик") {
                let cleaned = sanitize(localPart)
                guard !cleaned.isEmpty else {
                    store.flash("Введите имя ящика")
                    return
                }
                Haptics.success()
                focused = false
                settings.localPart = cleaned
                withAnimation(.easeOut(duration: 0.25)) { created = true }
            }
        }
    }

    // MARK: - Шаг 2: ящик создан

    private var createdStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            badge(symbol: "checkmark.shield")

            Text("Ящик создан")
                .font(.system(size: 27, weight: .semibold))
                .tracking(-0.68)
                .foregroundStyle(QM.text)
                .padding(.top, 18)

            Text("Ваш адрес:")
                .font(.system(size: 14.5))
                .foregroundStyle(QM.secondary)
                .padding(.top, 8)

            monoBox(settings.address, color: QM.text)
                .padding(.top, 8)

            (
                Text("Пароль для почтовых клиентов (IMAP/SMTP). Он показывается ")
                    .foregroundColor(QM.secondary)
                + Text("только один раз").foregroundColor(QM.text).bold()
                + Text(" — сохраните его сейчас.").foregroundColor(QM.secondary)
            )
            .font(.system(size: 13.5))
            .lineSpacing(3)
            .padding(.top, 18)

            monoBox(mailPassword, color: accent.tint)
                .padding(.top, 8)
                .textSelection(.enabled)

            Spacer(minLength: 20)

            primaryButton("Открыть почту") {
                Haptics.tap()
                settings.onboarded = true
                store.openInbox()
            }
        }
    }

    // MARK: - Кусочки

    private func badge(symbol: String) -> some View {
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

    private func monoBox(_ text: String, color: Color) -> some View {
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

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16.5, weight: .medium))
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
    }

    private func sanitize(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        let scalars = value.lowercased().unicodeScalars.filter { allowed.contains($0) && $0.isASCII }
        return String(String.UnicodeScalarView(scalars))
    }
}
