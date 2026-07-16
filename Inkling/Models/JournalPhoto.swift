import Foundation
import SwiftData

@Model
final class JournalPhoto {
    var id: String = UUID().uuidString
    @Attribute(.externalStorage) var imageData: Data = Data()
    var sortOrder: Int = 0
    var entry: JournalEntry?

    init(imageData: Data, sortOrder: Int = 0) {
        self.id = UUID().uuidString
        self.imageData = imageData
        self.sortOrder = sortOrder
    }
}
