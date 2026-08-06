import SwiftUI

/// Loads photo data asynchronously without blocking the main thread
struct AsyncPhotoView: View {
    let imageData: Data
    @State private var loadedImage: UIImage?

    var body: some View {
        Group {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
            } else {
                Rectangle()
                    .fill(Color.brown.opacity(0.05))
                    .overlay {
                        ProgressView()
                            .scaleEffect(0.6)
                    }
            }
        }
        .task {
            loadedImage = await Task.detached(priority: .userInitiated) {
                UIImage(data: imageData)
            }.value
        }
    }
}
