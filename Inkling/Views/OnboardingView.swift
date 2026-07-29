import SwiftUI

/// First-launch onboarding flow introducing key features
struct OnboardingView: View {
    @Binding var isPresented: Bool
    @AppStorage("fontStyle") private var fontStyle = FontStyle.songti.rawValue

    private var journalFont: Font {
        (FontStyle(rawValue: fontStyle) ?? .songti).makeFont(size: 16)
    }

    @State private var currentPage = 0

    private let features: [(icon: String, title: String, desc: String)] = [
        ("square.and.pencil", "onboarding.write_title", "onboarding.write_desc"),
        ("sparkles", "onboarding.ai_title", "onboarding.ai_desc"),
        ("chart.bar.fill", "onboarding.stats_title", "onboarding.stats_desc"),
        ("lock.shield.fill", "onboarding.privacy_title", "onboarding.privacy_desc"),
    ]

    var body: some View {
        ZStack {
            Color("JournalBackground")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button(String(localized: "onboarding.skip")) {
                        finishOnboarding()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                }

                Spacer()

                // Page content
                TabView(selection: $currentPage) {
                    ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                        featurePage(icon: feature.icon, title: feature.title, desc: feature.desc)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 320)

                Spacer()

                // Bottom controls
                VStack(spacing: 16) {
                    // Dot indicators (custom)
                    HStack(spacing: 8) {
                        ForEach(0..<features.count, id: \.self) { i in
                            Circle()
                                .fill(i == currentPage ? Color.brown : Color.brown.opacity(0.2))
                                .frame(width: 8, height: 8)
                        }
                    }

                    Button {
                        if currentPage < features.count - 1 {
                            withAnimation { currentPage += 1 }
                        } else {
                            finishOnboarding()
                        }
                    } label: {
                        Text(currentPage < features.count - 1
                             ? String(localized: "onboarding.next")
                             : String(localized: "onboarding.start"))
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.brown)
                    .padding(.horizontal, 40)
                }
                .padding(.bottom, 50)
            }
        }
    }

    private func featurePage(icon: String, title: String, desc: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(.brown)
                .padding(.bottom, 8)

            Text(LocalizedStringKey(title))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            Text(LocalizedStringKey(desc))
                .font(journalFont)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.horizontal, 40)
        }
    }

    private func finishOnboarding() {
        UserDefaults.standard.set(true, forKey: "onboarding_completed")
        withAnimation(.easeInOut(duration: 0.3)) {
            isPresented = false
        }
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}
