import SwiftUI

struct PrimaryStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
            .padding(.horizontal, 16).padding(.vertical, 10).background((isEnabled ? Color(red: 0, green: 0.43, blue: 0.38) : Color.gray).opacity(configuration.isPressed && isEnabled ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 9))
    }
}
