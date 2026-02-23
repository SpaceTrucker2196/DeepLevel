import SwiftUI

/// A 4-way directional controller for player movement.
///
/// Displays a cross-shaped D-pad in the bottom-right corner of the screen.
/// Each button sends a movement direction to the game scene.
///
/// - Since: 1.0.0
struct DirectionalController: View {
    /// Callback invoked when a direction button is pressed.
    var onDirection: (Int, Int) -> Void
    /// Callback invoked when the center stop button is pressed.
    var onStop: () -> Void

    private let buttonSize: CGFloat = 48
    private let spacing: CGFloat = 2

    var body: some View {
        VStack(spacing: spacing) {
            directionButton(dx: 0, dy: 1, systemName: "chevron.up")
            HStack(spacing: spacing) {
                directionButton(dx: -1, dy: 0, systemName: "chevron.left")
                stopButton
                directionButton(dx: 1, dy: 0, systemName: "chevron.right")
            }
            directionButton(dx: 0, dy: -1, systemName: "chevron.down")
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func directionButton(dx: Int, dy: Int, systemName: String) -> some View {
        Button {
            onDirection(dx, dy)
        } label: {
            Image(systemName: systemName)
                .font(.title2.bold())
                .frame(width: buttonSize, height: buttonSize)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private var stopButton: some View {
        Button {
            onStop()
        } label: {
            Image(systemName: "stop.fill")
                .font(.caption.bold())
                .frame(width: buttonSize, height: buttonSize)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
