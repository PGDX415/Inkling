import SwiftUI

/// Full-screen photo viewer with pinch-to-zoom and dismiss
struct FullScreenPhotoView: View {
    @Environment(\.dismiss) private var dismiss
    let imageData: Data

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = lastScale * value
                            }
                            .onEnded { _ in
                                withAnimation { lastScale = scale }
                                if scale < 1 { scale = 1; lastScale = 1 }
                            }
                    )
                    .onTapGesture {
                        dismiss()
                    }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding()
        }
        .statusBarHidden()
    }
}
