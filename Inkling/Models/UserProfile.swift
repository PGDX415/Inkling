import Foundation
import SwiftData

@Model
final class UserProfile {
    var name: String = ""
    var photoData: Data?

    init(name: String = "", photoData: Data? = nil) {
        self.name = name
        self.photoData = photoData
    }
}
