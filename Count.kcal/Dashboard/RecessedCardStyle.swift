import SwiftUI

/// A card face that presses halfway inward over a fixed bottom rim.
struct RecessedCardStyle: ButtonStyle {
    nonisolated static var rimDepth: CGFloat { 4 }
    let background: Color
    let feedback: RecessedCardFeedback
    let pulse: Int

    func makeBody(configuration: Configuration) -> some View {
        RecessedCardFace(
            face: configuration.label,
            background: background,
            feedback: feedback,
            pulse: pulse,
            isHeld: configuration.isPressed
        )
    }
}

private struct RecessedCardFace<Face: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let face: Face
    let background: Color
    let feedback: RecessedCardFeedback
    let pulse: Int
    let isHeld: Bool

    private var rimDepth: CGFloat { RecessedCardStyle.rimDepth }
    private var rimInset: CGFloat { 10 }

    var body: some View {
        let pressed = feedback.isDepressed
        let depth = pressed && !reduceMotion ? rimDepth : 0
        let sideInset = pressed && !reduceMotion ? rimInset * 0.5 : 0

        face
            // Press feedback must not change the label's own numeric animations.
            .transaction { $0.animation = nil }
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color("TextColor").opacity(0.06), lineWidth: 2)
                    .mask(alignment: .top) {
                        LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom)
                            .frame(height: 10)
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .visualEffect { effect, geometry in
                effect
                    .scaleEffect(max(0, 1 - 2 * sideInset / max(geometry.size.width, 1)), anchor: .bottom)
            }
            .offset(y: depth)
            .opacity(reduceMotion && pressed ? 0.85 : 1)
            .background {
                GeometryReader { geometry in
                    let rimScale = max(0, 1 - 2 * rimInset / max(geometry.size.width, 1))
                    // The wider pressed face covers the rim's inset corners.
                    Rectangle().fill(background)
                        .overlay { Color("TextColor").opacity(0.15) }
                        .overlay(alignment: .bottom) {
                            LinearGradient(colors: [.clear, .black.opacity(0.18)], startPoint: .bottom, endPoint: .top)
                                .frame(height: rimDepth)
                        }
                        .frame(height: geometry.size.height + rimDepth)
                        .clipShape(.rect(cornerRadius: 10 * rimScale))
                        .mask(alignment: .bottom) {
                            Rectangle().frame(height: rimDepth)
                        }
                        .padding(.horizontal, rimInset)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .padding(.bottom, rimDepth)
            .contentShape(.rect(cornerRadius: 10))
            .onAppear { feedback.appear(input) }
            .onChange(of: input) { _, input in
                feedback.updateInput(input)
            }
            .onDisappear { feedback.disappear() }
    }

    private var input: RecessedPress.Input {
        .init(isHeld: isHeld, pulse: pulse)
    }
}
