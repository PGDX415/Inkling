import SwiftUI

/// Launch splash screen with animated entrance
struct SplashView: View {
    @Binding var isActive: Bool
    @State private var opacity: Double = 0
    @State private var scale: Double = 0.85
    @State private var glowOpacity: Double = 0

    private let animationDuration: Double = 1.0
    private let displayDuration: Double = 2.0

    var body: some View {
        ZStack {
            // Deep warm gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.09, blue: 0.16),
                    Color(red: 0.16, green: 0.13, blue: 0.22),
                    Color(red: 0.12, green: 0.10, blue: 0.18),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Ambient golden glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.95, green: 0.78, blue: 0.35).opacity(glowOpacity * 0.4),
                            Color(red: 0.85, green: 0.60, blue: 0.20).opacity(glowOpacity * 0.15),
                            .clear,
                        ],
                        center: .center,
                        startRadius: 80,
                        endRadius: 400
                    )
                )
                .frame(width: 600, height: 600)
                .blur(radius: 30)

            // Content
            VStack(spacing: 28) {
                // Icon area — stylized book with light
                ZStack {
                    // Glow behind icon
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.95, green: 0.75, blue: 0.30).opacity(0.6),
                                    .clear,
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)

                    // Book icon
                    Image(systemName: "book.pages.fill")
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.95, green: 0.82, blue: 0.55),
                                    Color(red: 0.80, green: 0.58, blue: 0.25),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: Color(red: 0.9, green: 0.7, blue: 0.3).opacity(0.5), radius: 20)
                }

                // App name
                VStack(spacing: 8) {
                    Text("app.name")
                        .font(.system(size: 36, weight: .medium, design: .serif))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.95, green: 0.85, blue: 0.65),
                                    Color(red: 0.78, green: 0.58, blue: 0.32),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    Text("splash.subtitle")
                        .font(.system(size: 13, weight: .light, design: .serif))
                        .foregroundStyle(Color.white.opacity(0.35))
                        .tracking(1.5)
                }
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            animateIn()
        }
    }

    private func animateIn() {
        withAnimation(.easeOut(duration: animationDuration)) {
            opacity = 1
            scale = 1
        }

        withAnimation(.easeOut(duration: animationDuration * 1.2).delay(0.3)) {
            glowOpacity = 1
        }

        // Auto-dismiss after display duration
        DispatchQueue.main.asyncAfter(deadline: .now() + displayDuration) {
            withAnimation(.easeInOut(duration: 0.6)) {
                opacity = 0
                scale = 1.05
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                isActive = false
            }
        }
    }
}

#Preview {
    SplashView(isActive: .constant(true))
}
