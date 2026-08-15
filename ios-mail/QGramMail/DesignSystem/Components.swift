import SwiftUI

/// Круглый аватар с инициалом — цвет выводится из имени отправителя.
@MainActor
struct Avatar: View {
    let name: String
    var size: CGFloat = 40

    var body: some View {
        Circle()
            .fill(QM.avatarColor(for: name))
            .frame(width: size, height: size)
            .overlay(
                Text(QM.initial(for: name))
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(.white)
            )
    }
}

/// Заголовок группы: «ЯЩИК», «ПОВЕДЕНИЕ», «ВЛОЖЕНИЯ (2)».
@MainActor
struct SectionCaption: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(0.66)
            .foregroundStyle(QM.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Переключатель в стиле макета: дорожка 47×28, бегунок 22.
@MainActor
struct QMToggle: View {
    @Binding var isOn: Bool
    let accent: AccentTheme

    var body: some View {
        Capsule()
            .fill(isOn ? accent.base : Color(hex: "E9E9ED").opacity(0.16))
            .frame(width: 47, height: 28)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(.white)
                    .frame(width: 22, height: 22)
                    .shadow(color: .black.opacity(0.4), radius: 1.5, y: 1)
                    .padding(3)
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isOn)
    }
}

/// Строка-переключатель внутри карточки настроек.
@MainActor
struct ToggleRow: View {
    let title: String
    var caption: String?
    @Binding var isOn: Bool
    let accent: AccentTheme

    var body: some View {
        Button {
            Haptics.tap()
            isOn.toggle()
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15.5))
                        .foregroundStyle(QM.text)
                        .multilineTextAlignment(.leading)
                    if let caption {
                        Text(caption)
                            .font(.system(size: 12.5))
                            .foregroundStyle(QM.tertiary)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 8)
                QMToggle(isOn: $isOn, accent: accent)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Разделитель во всю ширину карточки.
@MainActor
struct HairLine: View {
    var body: some View {
        Rectangle().fill(QM.hairline).frame(height: 1)
    }
}

/// Полоса «Отправлено сегодня N из 50».
@MainActor
struct QuotaBar: View {
    let sent: Int
    let limit: Int
    let accent: AccentTheme

    private var fraction: Double {
        limit > 0 ? min(Double(sent) / Double(limit), 1) : 0
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Отправлено сегодня")
                Spacer()
                Text("\(sent) из \(limit)")
                    .monospacedDigit()
                    .foregroundStyle(QM.bright)
            }
            .font(.system(size: 12))
            .foregroundStyle(QM.secondary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(QM.track)
                    Capsule()
                        .fill(accent.base)
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 4)
            .animation(.easeInOut(duration: 0.9), value: fraction)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .qmCard()
    }
}

/// Всплывающее уведомление внизу экрана.
@MainActor
struct ToastView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13.5, weight: .medium))
            .foregroundStyle(QM.text)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(Color(hex: "232532").opacity(0.96))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(QM.borderStrong, lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 17, y: 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

/// Кнопка-ссылка в шапке («Ящики», «Готово», «Отмена»).
@MainActor
struct ChromeButton: View {
    let title: String
    var systemImage: String?
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 17))
            }
            .foregroundStyle(color)
        }
        .buttonStyle(.plain)
    }
}

/// Крупный заголовок экрана.
@MainActor
struct LargeTitle: View {
    let text: String
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(text)
                .font(.system(size: 33, weight: .bold))
                .tracking(-0.99)
                .foregroundStyle(QM.text)
            if let trailing, !trailing.isEmpty {
                Text(trailing)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(QM.tertiary)
            }
            Spacer(minLength: 0)
        }
    }
}
