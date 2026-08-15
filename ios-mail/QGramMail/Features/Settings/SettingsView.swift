import SwiftUI

@MainActor
struct SettingsView: View {
    @EnvironmentObject private var store: MailStore
    @EnvironmentObject private var settings: SettingsStore

    private var accent: AccentTheme { settings.accent }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    mailboxSection
                    styleSection
                    behaviourSection
                    clientSection
                    demoSection
                }
                .padding(.horizontal, 14)
                .padding(.top, 16)
                .padding(.bottom, 140)
            }
        }
        .background(QM.bg)
    }

    private var header: some View {
        LargeTitle(text: "Настройки")
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
            .overlay(alignment: .bottom) { HairLine() }
    }

    // MARK: - Ящик

    private var mailboxSection: some View {
        section("Ящик") {
            HStack {
                Text("Адрес").font(.system(size: 15.5)).foregroundStyle(QM.text)
                Spacer(minLength: 12)
                Text(settings.address)
                    .font(.system(size: 13.5, design: .monospaced))
                    .foregroundStyle(QM.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)

            HairLine()

            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("Лимит отправки").font(.system(size: 15.5)).foregroundStyle(QM.text)
                    Spacer()
                    Text("\(store.sentToday) из \(settings.dailyLimit)")
                        .font(.system(size: 13.5))
                        .monospacedDigit()
                        .foregroundStyle(QM.secondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(QM.track)
                        Capsule()
                            .fill(accent.base)
                            .frame(width: geo.size.width * min(Double(store.sentToday) / Double(settings.dailyLimit), 1))
                    }
                }
                .frame(height: 4)
                Text("Действует также почасовой лимит. Он нужен, чтобы домен qgram.im не попал в спам-списки.")
                    .font(.system(size: 12.5))
                    .lineSpacing(3)
                    .foregroundStyle(QM.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
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
            ToggleRow(title: "Группировать в переписки", isOn: $settings.groupThreads, accent: accent)
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
            IMAP: mail.qgram.im, порт 993, SSL/TLS
            SMTP: mail.qgram.im, порт 465, SSL/TLS
                   (или порт 587 с STARTTLS)
            Логин: \(settings.address)
            Пароль: отдельный пароль почты
            """)
            .font(.system(size: 12.5, design: .monospaced))
            .lineSpacing(7)
            .foregroundStyle(Color(hex: "B2B6CA"))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .qmCard()

            Button {
                store.flash("Новый пароль отправлен в уведомление")
            } label: {
                Text("Сбросить пароль почты")
                    .font(.system(size: 15.5, weight: .medium))
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
            .padding(.top, 2)

            Text("Пароль хранится только в виде хеша, поэтому посмотреть текущий нельзя — можно лишь выпустить новый.")
                .font(.system(size: 12))
                .lineSpacing(3)
                .foregroundStyle(QM.tertiary)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Демонстрационные состояния

    private var demoSection: some View {
        section("Демо-состояния") {
            ToggleRow(
                title: "Отправка приостановлена",
                caption: "Показывает предупреждение и экран блокировки",
                isOn: $settings.demoBlocked,
                accent: accent
            )
            HairLine()
            Button {
                Haptics.tap()
                settings.onboarded = false
            } label: {
                HStack {
                    Text("Показать онбординг заново")
                        .font(.system(size: 15.5))
                        .foregroundStyle(QM.text)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(QM.chevron)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
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
