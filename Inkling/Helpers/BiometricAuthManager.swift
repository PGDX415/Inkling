import LocalAuthentication
import Foundation

/// Manages biometric authentication (Face ID / Touch ID) with passcode fallback
final class BiometricAuthManager {
    static let shared = BiometricAuthManager()

    private init() {}

    /// The biometry type available on this device
    var biometryType: LABiometryType {
        let context = LAContext()
        var error: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
        return context.biometryType
    }

    /// Display name for the available biometry
    var biometryName: String {
        switch biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Passcode"
        }
    }

    /// Whether any authentication is available
    var isAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    /// Attempt authentication with biometrics, falling back to device passcode
    /// - Parameter reason: The reason string shown to the user
    /// - Returns: Whether authentication succeeded
    func authenticate(reason: String = "Unlock your journal") async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "Enter Passcode"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            print("BiometricAuth unavailable: \(error?.localizedDescription ?? "unknown")")
            return false
        }

        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
        } catch {
            print("BiometricAuth failed: \(error.localizedDescription)")
            return false
        }
    }
}
