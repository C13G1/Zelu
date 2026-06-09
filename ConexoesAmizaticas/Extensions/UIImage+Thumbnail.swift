//
//  UIImage+Thumbnail.swift
//  ConexoesAmizaticas
//
//  Shared image processing for profile pictures: produces a true square thumbnail so photos never
//  stretch when drawn into square containers (e.g. SpriteKit `fillTexture` on `FriendNode`).
//

import UIKit

extension UIImage {
    /// Center-crops to a square (aspect-fill) and scales to exactly `side`×`side`.
    ///
    /// Unlike `preparingThumbnail(of:)`, which keeps the original aspect ratio and can return a
    /// non-square image, this always returns a square. A non-square texture stretches when filled into
    /// the square `FriendNode` shape, which is what distorted friend photos on the initial view.
    func squareThumbnail(side: CGFloat) -> UIImage {
        let source = normalized // fix EXIF orientation first
        let edge = min(source.size.width, source.size.height)
        let cropOrigin = CGPoint(
            x: (source.size.width - edge) / 2,
            y: (source.size.height - edge) / 2
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1 // output is exactly side×side pixels, independent of screen scale
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            // Scale the whole source so the centered square region fills the side×side canvas.
            let scale = side / edge
            let drawSize = CGSize(width: source.size.width * scale, height: source.size.height * scale)
            let drawOrigin = CGPoint(x: -cropOrigin.x * scale, y: -cropOrigin.y * scale)
            source.draw(in: CGRect(origin: drawOrigin, size: drawSize))
        }
    }
}
