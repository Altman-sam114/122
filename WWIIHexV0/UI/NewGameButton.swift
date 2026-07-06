import SwiftUI

struct NewGameButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "arrow.counterclockwise")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .buttonStyle(.bordered)
    }
}
