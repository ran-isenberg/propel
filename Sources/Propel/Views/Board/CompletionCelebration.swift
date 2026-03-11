import SwiftUI

/// A brief celebration overlay with animated particles when a task is completed.
struct CompletionCelebration: View {
    @State private var particles: [Particle] = []
    @State private var isAnimating = false

    private let colors: [Color] = [.green, .yellow, .blue, .purple, .orange, .pink]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    particle.shape
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .position(
                            x: isAnimating ? particle.endX : geo.size.width / 2,
                            y: isAnimating ? particle.endY : geo.size.height * 0.3
                        )
                        .opacity(isAnimating ? 0 : 1)
                }
            }
            .onAppear {
                particles = (0 ..< 20).map { _ in
                    Particle(
                        color: colors.randomElement() ?? .blue,
                        size: CGFloat.random(in: 4 ... 8),
                        endX: CGFloat.random(in: 0 ... geo.size.width),
                        endY: CGFloat.random(in: -20 ... geo.size.height),
                        shape: Bool.random() ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 1))
                    )
                }
                withAnimation(.easeOut(duration: 1.0)) {
                    isAnimating = true
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct Particle: Identifiable {
    let id = UUID()
    let color: Color
    let size: CGFloat
    let endX: CGFloat
    let endY: CGFloat
    let shape: AnyShape
}
