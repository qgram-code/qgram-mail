import SwiftUI

@MainActor
struct SearchView: View {
    @EnvironmentObject private var store: MailStore
    @EnvironmentObject private var settings: SettingsStore
    @FocusState private var focused: Bool

    private var accent: AccentTheme { settings.accent }

    private let recents = ["договор", "счёт", "ревью"]

    private var results: [Message] { store.results(scopedTo: store.folder) }
    private var hasQuery: Bool { !store.query.trimmingCharacters(in: .whitespaces).isEmpty }

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
                        .focused($focused)
                    if hasQuery {
                        Button {
                            store.query = ""
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
                .background(Color(hex: "E9E9ED").opacity(0.09), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button("Отмена") {
                    focused = false
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
                    } label: {
                        Text(title(for: scope))
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(selected ? accent.tint : QM.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selected ? accent.base.opacity(0.16) : .clear, in: Capsule())
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
                VStack(alignment: .leading, spacing: 0) {
                    SectionCaption(text: "Недавние запросы")
                        .padding(.bottom, 8)
                    ForEach(recents, id: \.self) { recent in
                        Button {
                            store.query = recent
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(QM.faint)
                                Text(recent)
                                    .font(.system(size: 15))
                                    .foregroundStyle(QM.bright)
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 11)
                            .padding(.horizontal, 2)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .overlay(alignment: .bottom) { HairLine() }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            } else if results.isEmpty {
                VStack(spacing: 4) {
                    Text("Ничего не найдено")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(QM.bright)
                    Text("Попробуйте другой запрос.")
                        .font(.system(size: 13.5))
                        .foregroundStyle(QM.tertiary)
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
                            HStack(alignment: .top, spacing: 11) {
                                Avatar(name: message.name)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Text(message.name)
                                            .font(.system(size: 15.5, weight: .semibold))
                                            .foregroundStyle(QM.text)
                                            .lineLimit(1)
                                        Spacer(minLength: 0)
                                        Text(message.time)
                                            .font(.system(size: 12.5))
                                            .foregroundStyle(QM.tertiary)
                                    }
                                    Text(message.subject)
                                        .font(.system(size: 14.5))
                                        .foregroundStyle(QM.subject)
                                        .lineLimit(1)
                                    Text(message.preview)
                                        .font(.system(size: 13.5))
                                        .foregroundStyle(QM.tertiary)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
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
}
