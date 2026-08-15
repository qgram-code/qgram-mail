import SwiftUI

@MainActor
struct ComposeView: View {
    @EnvironmentObject private var store: MailStore
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var session: Session
    @FocusState private var focus: Field?

    private enum Field: Hashable { case to, cc, subject, body }

    private var accent: AccentTheme { settings.accent }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            ScrollView {
                VStack(spacing: 0) {
                    fromRow
                    HairLine()
                    field(label: "Кому", text: $store.draft.to, placeholder: "name@example.com", field: .to)
                        .keyboardType(.emailAddress)
                    HairLine()
                    field(label: "Копия", text: $store.draft.cc, placeholder: "необязательно", field: .cc)
                        .keyboardType(.emailAddress)
                    HairLine()
                    field(label: "Тема", text: $store.draft.subject, placeholder: "Без темы", field: .subject)
                    HairLine()

                    TextEditor(text: $store.draft.body)
                        .focused($focus, equals: .body)
                        .font(.system(size: 15.5))
                        .lineSpacing(5)
                        .foregroundStyle(Color(hex: "E4E5EC"))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 210)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .overlay(alignment: .topLeading) {
                            if store.draft.body.isEmpty {
                                Text("Текст письма")
                                    .font(.system(size: 15.5))
                                    .foregroundStyle(QM.tertiary)
                                    .padding(.horizontal, 17)
                                    .padding(.vertical, 16)
                                    .allowsHitTesting(false)
                            }
                        }

                    HStack(spacing: 8) {
                        Text("Вложения через API пока не поддерживаются")
                            .font(.system(size: 12))
                            .foregroundStyle(QM.faint)
                        Spacer(minLength: 0)
                        Text("\(session.sentToday) из \(session.dailyLimit) за сегодня")
                            .font(.system(size: 12))
                            .monospacedDigit()
                            .foregroundStyle(QM.tertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 14)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(QM.sheet)
        .onAppear { focus = store.draft.to.isEmpty ? .to : .body }
    }

    private var toolbar: some View {
        HStack {
            Button("Отмена") { store.composeOpen = false }
                .font(.system(size: 16.5))
                .foregroundStyle(accent.base)
                .buttonStyle(.plain)

            Spacer()
            Text(store.draft.inReplyTo == nil ? "Новое письмо" : "Ответ")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(QM.text)
            Spacer()

            Button {
                Task { await store.send() }
            } label: {
                ZStack {
                    Text("Отправить")
                        .font(.system(size: 14.5, weight: .semibold))
                        .opacity(store.sending ? 0 : 1)
                    if store.sending {
                        ProgressView().tint(QM.bg)
                    }
                }
                .foregroundStyle(QM.bg)
                .padding(.horizontal, 15)
                .padding(.vertical, 7)
                .background(accent.base, in: Capsule())
            }
            .buttonStyle(TapScaleStyle(scale: 0.94))
            .disabled(store.sending || session.sendingBlocked)
            .opacity(session.sendingBlocked ? 0.5 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) { HairLine() }
    }

    private var fromRow: some View {
        HStack(spacing: 10) {
            Text("От")
                .font(.system(size: 15.5))
                .foregroundStyle(QM.tertiary)
                .frame(width: 56, alignment: .leading)
            Text(session.address)
                .font(.system(size: 13.5, design: .monospaced))
                .foregroundStyle(QM.secondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func field(label: String, text: Binding<String>, placeholder: String, field: Field) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 15.5))
                .foregroundStyle(QM.tertiary)
                .frame(width: 56, alignment: .leading)
            TextField("", text: text, prompt: Text(placeholder).foregroundColor(QM.tertiary))
                .font(.system(size: 15.5))
                .foregroundStyle(QM.title)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focus, equals: field)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
