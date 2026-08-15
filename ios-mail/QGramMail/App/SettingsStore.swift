import SwiftUI

/// Пользовательские настройки приложения. Всё, что здесь лежит, переживает
/// перезапуск — хранится в UserDefaults.
final class SettingsStore: ObservableObject {
    private enum Key {
        static let accent = "qm.accentHex"
        static let showQuota = "qm.showQuota"
        static let swipes = "qm.swipes"
        static let threads = "qm.threads"
        static let lockPreview = "qm.lockPreview"
        static let onboarded = "qm.onboarded"
        static let localPart = "qm.localPart"
        static let demoBlocked = "qm.demoBlocked"
    }

    private let defaults: UserDefaults

    /// Акцентный цвет интерфейса (настраивается на экране «Настройки → Стиль»).
    @Published var accentHex: String { didSet { defaults.set(accentHex, forKey: Key.accent) } }
    /// Показывать ли плашку с квотой отправки на главном экране.
    @Published var showQuota: Bool { didSet { defaults.set(showQuota, forKey: Key.showQuota) } }

    @Published var swipesEnabled: Bool { didSet { defaults.set(swipesEnabled, forKey: Key.swipes) } }
    @Published var groupThreads: Bool { didSet { defaults.set(groupThreads, forKey: Key.threads) } }
    @Published var lockScreenPreview: Bool { didSet { defaults.set(lockScreenPreview, forKey: Key.lockPreview) } }

    @Published var onboarded: Bool { didSet { defaults.set(onboarded, forKey: Key.onboarded) } }
    @Published var localPart: String { didSet { defaults.set(localPart, forKey: Key.localPart) } }
    /// Демо-переключатель: показывает состояние «отправка приостановлена».
    @Published var demoBlocked: Bool { didSet { defaults.set(demoBlocked, forKey: Key.demoBlocked) } }

    var accent: AccentTheme { AccentTheme(hex: accentHex) }
    var address: String { "\(localPart)@qgram.im" }

    /// Суточный лимит отправки (в макете — параметр `dailyLimit`).
    let dailyLimit = 50

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.accent: AccentOption.default.hex,
            Key.showQuota: true,
            Key.swipes: true,
            Key.threads: true,
            Key.lockPreview: false,
            Key.onboarded: false,
            Key.localPart: "nikita",
            Key.demoBlocked: false
        ])
        accentHex = defaults.string(forKey: Key.accent) ?? AccentOption.default.hex
        showQuota = defaults.bool(forKey: Key.showQuota)
        swipesEnabled = defaults.bool(forKey: Key.swipes)
        groupThreads = defaults.bool(forKey: Key.threads)
        lockScreenPreview = defaults.bool(forKey: Key.lockPreview)
        onboarded = defaults.bool(forKey: Key.onboarded)
        localPart = defaults.string(forKey: Key.localPart) ?? "nikita"
        demoBlocked = defaults.bool(forKey: Key.demoBlocked)
    }
}
