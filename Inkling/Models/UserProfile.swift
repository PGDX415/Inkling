import Foundation
import SwiftData

/// Singleton user profile synced via CloudKit.
/// Uses a fixed UUID so there is exactly one profile across all devices.
@Model
final class UserProfile {
    /// Fixed identifier ensures only one profile exists
    static let fixedID = "INKLING_USER_PROFILE"

    var id: String = UserProfile.fixedID
    var name: String = ""
    var photoData: Data?

    init(name: String = "", photoData: Data? = nil) {
        self.id = Self.fixedID
        self.name = name
        self.photoData = photoData
    }
}
