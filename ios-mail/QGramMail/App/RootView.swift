import SwiftUI

@MainActor
struct RootView: View {
    @EnvironmentObject private var store: MailStore
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        ZStack {
            QM.bg.ignoresSafeArea()

            if !settings.onboarded {
                OnboardingView()
                    .transition(.opacity)
            } else {
                content
                    .transition(.opacity)

                if store.showsTabBar {
                    VStack {
                        Spacer()
                        ZStack(alignment: .bottomTrailing) {
                            TabBar()
                            ComposeButton()
                                .padding(.trailing, 18)
                                .offset(y: -104)
                        }
                    }
                    .ignoresSafeArea(.keyboard)
                }
            }

            if let toast = store.toast {
                VStack {
                    Spacer()
                    ToastView(text: toast)
                        .padding(.bottom, 160)
                }
                .allowsHitTesting(false)
                .zIndex(80)
            }
        }
        .animation(.easeOut(duration: 0.2), value: settings.onboarded)
        .sheet(isPresented: $store.composeOpen) {
            ComposeView()
                .environmentObject(store)
                .environmentObject(settings)
                .preferredColorScheme(.dark)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.screen {
        case .list: MailListView()
        case .message: MessageView()
        case .folders: FoldersView()
        case .search: SearchView()
        case .settings: SettingsView()
        case .blocked: BlockedView()
        }
    }
}

/// Нижняя панель: Почта · Поиск · Настройки.
@MainActor
private struct TabBar: View {
    @EnvironmentObject private var store: MailStore
    @EnvironmentObject private var settings: SettingsStore

    private struct Item {
        let screen: Screen
        let label: String
        let symbol: String
        let badge: Int
    }

    private var items: [Item] {
        [
            Item(screen: .list, label: "Почта", symbol: "tray", badge: store.unseenInbox),
            Item(screen: .search, label: "Поиск", symbol: "magnifyingglass", badge: 0),
            Item(screen: .settings, label: "Настройки", symbol: "gearshape", badge: 0)
        ]
    }

    private func isActive(_ item: Item) -> Bool {
        store.screen == item.screen || (item.screen == .list && store.screen == .folders)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(items, id: \.screen) { item in
                Button {
                    Haptics.tap()
                    store.go(to: item.screen)
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            Image(systemName: item.symbol)
                                .font(.system(size: 22, weight: .regular))
                            if item.badge > 0 {
                                Text("\(item.badge)")
                                    .font(.system(size: 10.5, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .frame(minWidth: 17, minHeight: 17)
                                    .background(QM.badge, in: Capsule())
                                    .offset(x: 15, y: -9)
                            }
                        }
                        .frame(height: 25)
                        Text(item.label)
                            .font(.system(size: 10.5, weight: .medium))
                    }
                    .foregroundStyle(isActive(item) ? settings.accent.base : QM.tabIdle)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(TapScaleStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 9)
        .padding(.bottom, 6)
        .qmChromeBackground(edge: .bottom)
    }
}

/// Плавающая кнопка «написать письмо».
@MainActor
private struct ComposeButton: View {
    @EnvironmentObject private var store: MailStore
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        Button {
            store.composeNew(blocked: settings.demoBlocked)
        } label: {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(QM.bg)
                .frame(width: 56, height: 56)
                .background(settings.accent.base, in: Circle())
                .shadow(color: settings.accent.glow, radius: 14, y: 10)
        }
        .buttonStyle(TapScaleStyle())
    }
}

/// Нажатие «вдавливает» элемент — как в макете (`style-active: scale(.9)`).
struct TapScaleStyle: ButtonStyle {
    var scale: CGFloat = 0.9

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
