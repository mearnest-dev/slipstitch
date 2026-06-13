import SwiftUI

/// Full-screen photo viewer: the whole image scaled to fit, pinch to zoom,
/// drag to pan when zoomed, double-tap to toggle, X (or swipe down) to close.
struct FullScreenPhotoView: View {
    let url: URL

    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(zoomGesture.simultaneously(with: panGesture))
                        .onTapGesture(count: 2) {
                            withAnimation(.snappy) {
                                if scale > 1 {
                                    reset()
                                } else {
                                    scale = 2.5
                                    lastScale = 2.5
                                }
                            }
                        }
                case .empty:
                    ProgressView().tint(.white)
                case .failure:
                    VStack(spacing: StitchTheme.Spacing.sm) {
                        Image(systemName: "photo")
                        Text("Couldn't load image")
                            .font(StitchTheme.Font.caption)
                    }
                    .foregroundStyle(.white.opacity(0.7))
                @unknown default:
                    EmptyView()
                }
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.5))
            }
            .padding(StitchTheme.Spacing.md)
        }
        // Swipe down to dismiss when not zoomed in.
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if scale <= 1.01 && value.translation.height > 80 {
                        dismiss()
                    }
                }
        )
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(lastScale * value, 1), 5)
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1.01 { withAnimation(.snappy) { reset() } }
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1 else { return }
                offset = CGSize(width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height)
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private func reset() {
        scale = 1
        lastScale = 1
        offset = .zero
        lastOffset = .zero
    }
}

/// Convenience: makes any image-bearing view tappable to open the full photo.
extension View {
    func fullScreenPhoto(url urlString: String?, isPresented: Binding<Bool>) -> some View {
        fullScreenCover(isPresented: isPresented) {
            if let urlString, let url = URL(string: urlString) {
                FullScreenPhotoView(url: url)
            }
        }
    }
}
