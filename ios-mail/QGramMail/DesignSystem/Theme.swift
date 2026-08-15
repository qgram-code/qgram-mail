import SwiftUI
import UIKit

// Палитра перенесена из макета «QGram Mail iOS» (Nocturne, тёмная тема).
enum QM {
    // Поверхности
    static let bg = Color(hex: "12141F")
    static let card = Color(hex: "1B1D2A")
    static let sheet = Color(hex: "191B28")
    static let scrim = Color(hex: "04050A")

    // Текст
    static let title = Color(hex: "F3F5FE")
    static let text = Color(hex: "E9E9ED")
    static let body = Color(hex: "DCDDE6")
    static let subject = Color(hex: "DFE0E8")
    static let bright = Color(hex: "CFD3E5")
    static let secondary = Color(hex: "9397AB")
    static let tertiary = Color(hex: "75798C")
    static let faint = Color(hex: "5D6070")
    static let chevron = Color(hex: "4D5162")
    static let tabIdle = Color(hex: "6B6F80")

    // Линии и заливки
    static let hairline = Color(hex: "E9E9ED").opacity(0.07)
    static let border = Color(hex: "E9E9ED").opacity(0.08)
    static let borderStrong = Color(hex: "E9E9ED").opacity(0.12)
    static let fill = Color(hex: "E9E9ED").opacity(0.08)
    static let track = Color(hex: "E9E9ED").opacity(0.10)

    // Акценты состояний
    static let danger = Color(hex: "E06A60")
    static let deleteSwipe = Color(hex: "C0392F")
    static let archiveSwipe = Color(hex: "5D5294")
    static let warn = Color(hex: "F0A13A")
    static let warnText = Color(hex: "F5C97A")
    static let badge = Color(hex: "E0574C")
    static let online = Color(hex: "4BA36B")

    // Цвета аватаров — тот же список и та же хеш-функция, что в макете.
    static let avatarHues = ["6F63B8", "4F7FB0", "A86A52", "4F9070", "8A5F96", "B0894F", "5F6F9A"]

    static func avatarColor(for name: String) -> Color {
        var h = 0
        for scalar in name.unicodeScalars {
            h = (h &* 31 &+ Int(scalar.value)) % avatarHues.count
        }
        return Color(hex: avatarHues[abs(h) % avatarHues.count])
    }

    static func initial(for name: String) -> String {
        String(name.first ?? "—")
    }
}

/// Акцентный цвет и производные от него оттенки (заливка, обводка, светлый текст).
struct AccentTheme {
    let hex: String

    var base: Color { Color(hex: hex) }
    var soft: Color { base.opacity(0.14) }
    var softer: Color { base.opacity(0.10) }
    var pressed: Color { base.opacity(0.24) }
    var line: Color { base.opacity(0.45) }
    /// Светлый вариант для текста на тёмной заливке (в макете — #D2CEFD).
    var tint: Color { base.mixed(with: .white, amount: 0.58) }
    var glow: Color { base.opacity(0.34) }
}

/// Доступные акцентные цвета. Первые четыре — из макета.
struct AccentOption: Identifiable, Hashable {
    let hex: String
    let name: String
    var id: String { hex }

    static let all: [AccentOption] = [
        AccentOption(hex: "9184D9", name: "Сирень"),
        AccentOption(hex: "7FB0D9", name: "Лёд"),
        AccentOption(hex: "C08A6A", name: "Медь"),
        AccentOption(hex: "7FC0A0", name: "Мята"),
        AccentOption(hex: "D98AA8", name: "Роза"),
        AccentOption(hex: "C9A94F", name: "Янтарь")
    ]

    static let `default` = all[0]
}

extension Color {
    init(hex: String) {
        var raw = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.hasPrefix("#") { raw.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: raw).scanHexInt64(&value)
        let r, g, b, a: Double
        if raw.count == 8 {
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        } else {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    /// Линейное смешивание в sRGB — нужно, чтобы вывести светлый оттенок акцента.
    func mixed(with other: Color, amount: Double) -> Color {
        let a = UIColor(self).rgba
        let b = UIColor(other).rgba
        let t = min(max(amount, 0), 1)
        return Color(
            .sRGB,
            red: a.r + (b.r - a.r) * t,
            green: a.g + (b.g - a.g) * t,
            blue: a.b + (b.b - a.b) * t,
            opacity: a.a + (b.a - a.a) * t
        )
    }
}

private extension UIColor {
    var rgba: (r: Double, g: Double, b: Double, a: Double) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
    }
}

extension View {
    /// Полупрозрачная «стеклянная» подложка шапок и таб-бара из макета.
    func qmChromeBackground(edge: Edge.Set) -> some View {
        background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(QM.bg.opacity(0.86))
                .overlay(alignment: edge == .top ? .bottom : .top) {
                    Rectangle().fill(QM.border).frame(height: 1)
                }
                .ignoresSafeArea(edges: edge)
        }
    }

    func qmCard() -> some View {
        background(QM.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(QM.border, lineWidth: 1)
            )
    }
}

@MainActor
enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
