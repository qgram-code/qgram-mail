import SwiftUI

/// Пользовательские настройки приложения. Всё, что здесь лежит, переживает
/// перезапуск — хранится в UserDefaults. Данные аккаунта и ящика живут
/// в `Session` и приходят с сервера.
final class SettingsStore: ObservableObject {
    private enum Key {
        static let accent = "qm.accentHex"
        static let showQuota = "qm.showQuota"
        static let swipes = "qm.swipes"
        static let previews = "qm.previews"
        static let lockPreview = "qm.lockPreview"
    }

    private let defaults: UserDefaults

    /// Акцентный цвет интерфейса (настраивается на экране «Настройки → Стиль»).
    @Published var accentHex: String { didSet { defaults.set(accentHex, forKey: Key.accent) } }
    /// Показывать ли плашку с квотой отправки на главном экране.
    @Published var showQuota: Bool { didSet { defaults.set(showQuota, forKey: Key.showQuota) } }

    @Published var swipesEnabled: Bool { didSet { defaults.set(swipesEnabled, forKey: Key.swipes) } }
    /// Подтягивать ли текст письма в список (запрос `peek=1` на каждое письмо).
    @Published var showPreviews: Bool { didSet { defaults.set(showPreviews, forKey: Key.previews) } }
    @Published var lockScreenPreview: Bool { didSet { defaults.set(lockScreenPreview, forKey: Key.lockPreview) } }

    var accent: AccentTheme { AccentTheme(hex: accentHex) }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.accent: AccentOption.default.hex,
            Key.showQuota: true,
            Key.swipes: true,
            Key.previews: true,
            Key.lockPreview: false
        ])
        accentHex = defaults.string(forKey: Key.accent) ?? AccentOption.default.hex
        showQuota = defaults.bool(forKey: Key.showQuota)
        swipesEnabled = defaults.bool(forKey: Key.swipes)
        showPreviews = defaults.bool(forKey: Key.previews)
        lockScreenPreview = defaults.bool(forKey: Key.lockPreview)
    }
}
