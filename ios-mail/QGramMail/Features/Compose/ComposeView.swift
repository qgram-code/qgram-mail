import SwiftUI

@MainActor
struct ComposeView: View {
    @EnvironmentObject private var store: MailStore
    @EnvironmentObject private var settings: SettingsStore
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
                        Button {
                            store.flash("Вложения — в следующей итерации")
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: "paperclip").font(.system(size: 14, weight: .medium))
                                Text("Вложение").font(.system(size: 13.5, weight: .medium))
                            }
                            .foregroundStyle(QM.bright)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 9)
                            .background(Color(hex: "E9E9ED").opacity(0.05), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .strokeBorder(QM.borderStrong, lineWidth: 1)
                            )
                        }
                        .buttonStyle(TapScaleStyle(scale: 0.96))

                        Text("\(store.sentToday) из \(settings.dailyLimit) за сегодня")
                            .font(.system(size: 12))
                            .foregroundStyle(QM.tertiary)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
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
            Text("Новое письмо")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(QM.text)
            Spacer()

            Button {
                store.send()
            } label: {
                Text("Отправить")
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(QM.bg)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 7)
                    .background(accent.base, in: Capsule())
            }
            .buttonStyle(TapScaleStyle(scale: 0.94))
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
            Text(settings.address)
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
