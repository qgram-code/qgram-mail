import SwiftUI

/// Поиск по письмам. Запрос уходит на сервер (`GET /api/mail/messages?q=`),
/// область «Все ящики» опрашивает все шесть папок.
@MainActor
struct SearchView: View {
    @EnvironmentObject private var store: MailStore
    @EnvironmentObject private var settings: SettingsStore
    @FocusState private var focused: Bool

    private var accent: AccentTheme { settings.accent }

    private var results: [MailMessage] { store.searchResults }
    private var hasQuery: Bool { store.query.trimmingCharacters(in: .whitespaces).count >= 2 }

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .background(QM.bg)
        .onAppear { focused = true }
    }

    private var header: some View {
        VStack(spacing: 11) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(QM.tertiary)
                    TextField("", text: $store.query, prompt: Text("Поиск в письмах").foregroundColor(QM.tertiary))
                        .font(.system(size: 16))
                        .foregroundStyle(QM.title)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .focused($focused)
                        .onSubmit { store.runSearch() }
                        .onChange(of: store.query) { _ in store.runSearch() }
                    if !store.query.isEmpty {
                        Button {
                            store.clearSearch()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(QM.faint)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(QM.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button("Отмена") {
                    focused = false
                    store.clearSearch()
                    store.openInbox()
                }
                .font(.system(size: 16))
                .foregroundStyle(accent.base)
                .buttonStyle(.plain)
            }

            HStack(spacing: 7) {
                ForEach(SearchScope.allCases, id: \.self) { scope in
                    let selected = store.scope == scope
                    Button {
                        store.scope = scope
                        store.runSearch()
                    } label: {
                        Text(title(for: scope))
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(selected ? accent.tint : QM.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selected ? accent.soft : .clear, in: Capsule())
                            .overlay(
                                Capsule().strokeBorder(selected ? accent.base : QM.borderStrong, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
        .overlay(alignment: .bottom) { HairLine() }
    }

    private func title(for scope: SearchScope) -> String {
        switch scope {
        case .all: return "Все ящики"
        case .folder: return store.folderLabel
        case .unread: return "Непрочитанные"
        }
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            if !hasQuery {
                hint
            } else if store.searching {
                VStack(spacing: 10) {
                    ProgressView().tint(accent.base)
                    Text("Ищем на сервере…")
                        .font(.system(size: 13.5))
                        .foregroundStyle(QM.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 70)
            } else if results.isEmpty {
                VStack(spacing: 4) {
                    Text("Ничего не найдено")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(QM.bright)
                    Text("Поиск идёт по всему тексту письма — попробуйте другой запрос.")
                        .font(.system(size: 13.5))
                        .foregroundStyle(QM.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 70)
                .padding(.horizontal, 26)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(results) { message in
                        Button {
                            focused = false
                            store.open(message)
                        } label: {
                            row(message)
                        }
                        .buttonStyle(.plain)
                        .overlay(alignment: .bottom) { HairLine() }
                    }
                }
            }

            Color.clear.frame(height: 130)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var hint: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionCaption(text: "Как искать")
            Text("""
            Введите минимум два символа — запрос уходит на сервер и ищется \
            по теме, отправителю и тексту письма (IMAP TEXT). \
            Область «Все ящики» просматривает все шесть папок.
            """)
                .font(.system(size: 13.5))
                .lineSpacing(4)
                .foregroundStyle(QM.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 18)
    }

    private func row(_ message: MailMessage) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Avatar(name: message.displayName)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(message.displayName)
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(QM.text)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(message.time)
                        .font(.system(size: 12.5))
                        .foregroundStyle(QM.tertiary)
                }
                Text(message.displaySubject)
                    .font(.system(size: 14.5))
                    .foregroundStyle(QM.subject)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(MailFolder.label(for: message.folder))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(QM.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .overlay(Capsule().strokeBorder(QM.borderStrong, lineWidth: 1))
                    Text(message.fromAddress)
                        .font(.system(size: 12))
                        .foregroundStyle(QM.faint)
                        .lineLimit(1)
                }
                .padding(.top, 3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
