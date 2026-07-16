import SwiftUI

/// Full-screen lock overlay shown when the app is locked
struct LockView: View {
    @Binding var isLocked: Bool
    @State private var isAuthenticating = false
    @State private var authFailed = false

    var body: some View {
        ZStack {
            // Warm paper-like background
            Color("JournalBackground")
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // App icon / emblem
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.brown.opacity(0.7), .brown.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(.bottom, 8)

                Text("lock.title")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                if authFailed {
                    Text("lock.unlock_prompt")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .transition(.opacity)
                } else {
                    Text("lock.unlock_prompt")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Button {
                    authenticate()
                } label: {
                    if isAuthenticating {
                        ProgressView()
                            .tint(.brown)
                    } else {
                        Text(authFailed
                             ? String(localized: "lock.retry")
                             : String(localized: "lock.unlock")
                        )
                        .fontWeight(.medium)
                    }
                }
                .buttonStyle(.bordered)
                .tint(.brown)
                .disabled(isAuthenticating)
                .padding(.top, 16)

                Spacer()
            }
        }
        .onAppear {
            authenticate()
        }
    }

    private func authenticate() {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        authFailed = false

        Task {
            let success = await BiometricAuthManager.shared.authenticate(
                reason: String(localized: "lock.biometric_reason")
            )
            await MainActor.run {
                isAuthenticating = false
                if success {
                    withAnimation(.easeOut(duration: 0.3)) {
                        isLocked = false
                    }
                } else {
                    withAnimation {
                        authFailed = true
                    }
                }
            }
        }
    }
}

#Preview {
    LockView(isLocked: .constant(true))
}
