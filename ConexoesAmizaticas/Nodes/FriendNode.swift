//
//  FriendNode.swift
//  ConexoesAmizaticas
//
//  Created by Thomas Pinheiro Grandin on 20/05/26.
//
import SwiftUI
import SpriteKit
import UIKit

extension UIImage {
    var normalized: UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

/// The interactive visual representation of a connection in the physics simulation.
///
/// `FriendNode` combines the friend's profile picture with a colored stroke representing their current `RelationshipState`.
/// Its size and designated orbit are directly derived from the connection's `score`. It handles user interactions,
/// distinguishing between being dragged around the screen elastically and being tapped to open the profile details.
class FriendNode: SKShapeNode {
    var scale: CGFloat = 0.05
    var currentTouch: UITouch?
    
    /// The health score of the connection, determining its visual scale and orbital tier.
    var score: Double
    
    /// The inner graphical representation holding the user's avatar.
    var sprite: SKShapeNode!
    
    /// The target distance from the center of the scene.
    var orbitRadius: Double = RelationshipState.estaveis.orbitRadius
    
    var lastTouchLocation: CGPoint!
    private var touchStartLocation: CGPoint?
    private var lastTapTime: TimeInterval = 0

    /// A closure triggered when the node is tapped.
    /// Used by the parent scene to route the user to the `FriendsProfileView`.
    var onTapped: (() -> Void)?

    /// Initializes a new interactive node based on a specific connection's state.
    /// - Parameter connection: The `Connection` model containing the user data and relationship score.
    init(connection: Connection) {
        self.score = connection.metaManager.score
        let state = connection.metaManager.currentRelationshipState
        let imageData = connection.friend.profilePicture
        let path = UIBezierPath(roundedRect: CGRect(x: -128, y: -128, width: 256, height: 256), cornerRadius: 128).cgPath

        self.sprite = SKShapeNode(path: path)
        // Square-crop so a non-square photo doesn't stretch when SpriteKit fills the square shape.
        let image = (UIImage(data: imageData) ?? UIImage()).squareThumbnail(side: 256)
        self.sprite.fillTexture = SKTexture(image: image)
        self.sprite.fillColor = .white
        self.sprite.strokeColor = state.color
        self.sprite.lineWidth = 20
        super.init()

        self.name = connection.friend.id.uuidString
        // 138 = 128 (path radius) + 10 (the colored stroke that sits outside the path) so colored
        // borders meet edge-to-edge with the spiral and with other friend nodes without overlapping.
        self.physicsBody = SKPhysicsBody(circleOfRadius: 138)
        self.physicsBody?.isDynamic = true
        self.physicsBody?.affectedByGravity = false

        self.isUserInteractionEnabled = false
        let nodeScale = state.nodeSize / 256.0
        self.scale = nodeScale
        self.setScale(nodeScale)
        self.isUserInteractionEnabled = true
        self.orbitRadius = state.orbitRadius

        self.addChild(sprite)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let parent = self.parent else { return }
        currentTouch = touch
        let loc = touch.location(in: parent)
        lastTouchLocation = loc
        touchStartLocation = loc
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let parent = self.parent else { return }
        lastTouchLocation = touch.location(in: parent)
        currentTouch = touch
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        defer {
            currentTouch = nil
            touchStartLocation = nil
        }

        // Differentiate a tap from a drag — 22pt matches iOS's own tap tolerance (~half a finger width)
        if let touch = touches.first, let parent = self.parent, let start = touchStartLocation {
            let end = touch.location(in: parent)
            let dx = end.x - start.x
            let dy = end.y - start.y
            let now = CACurrentMediaTime()
            if sqrt(dx * dx + dy * dy) < 22, now - lastTapTime > 0.4 {
                lastTapTime = now
                onTapped?()
                return
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        currentTouch = nil
        touchStartLocation = nil
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Updates the node's position to follow the user's finger.
    /// Called sequentially by `FriendsScene` during the scene's update loop.
    func update() {
        if let _ = currentTouch {
            self.position.x += lastTouchLocation.x - self.position.x
            self.position.y += lastTouchLocation.y - self.position.y
        }
    }
}

#Preview{
    InitialView()
}
