import SwiftUI
import UIKit

struct StripScrollView: UIViewRepresentable {
    let image: CGImage?

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 8.0
        scrollView.showsVerticalScrollIndicator = true
        scrollView.backgroundColor = .black
        scrollView.delegate = context.coordinator

        let imageView = UIImageView()
        imageView.contentMode = .top
        imageView.backgroundColor = .black
        imageView.tag = 100
        scrollView.addSubview(imageView)
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        guard let imageView = scrollView.viewWithTag(100) as? UIImageView else { return }
        if let cgImage = image {
            let uiImage = UIImage(cgImage: cgImage)
            imageView.image = uiImage
            let scale = scrollView.bounds.width > 0 ? scrollView.bounds.width / CGFloat(cgImage.width) : 1
            let displayHeight = CGFloat(cgImage.height) * scale
            imageView.frame = CGRect(x: 0, y: 0, width: scrollView.bounds.width, height: displayHeight)
            scrollView.contentSize = imageView.frame.size
            // Auto-scroll to bottom (newest row)
            if scrollView.contentSize.height > scrollView.bounds.height {
                scrollView.setContentOffset(
                    CGPoint(x: 0, y: scrollView.contentSize.height - scrollView.bounds.height),
                    animated: false
                )
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            scrollView.viewWithTag(100)
        }
    }
}
