//
//  FriendsScene.swift
//  ConexoesAmizaticas
//
//  Created by Thomas Pinheiro Grandin on 20/05/26.
//

import SpriteKit

let MAX_RADIUS: Double = 400
let MIN_RADIUS: Double = 100

/// An interactive physics-based scene representing the user's active social universe.
///
/// `FriendsScene` visualizes `Connection` objects as orbiting planetary nodes around a central hub (the spiral).
/// It handles complex touch gestures like dragging nodes elastically and panning the entire camera view
/// to explore the relationship graph.
class FriendsScene: SKScene {
    var connections: Set<Connection> = Set()
    
    var firstTouch: UITouch!
    var secondTouch: UITouch!
    var pinchDistance: Double!
    var touchOffset: CGFloat = 0
    var rootNode: SKNode = SKNode()
    let sceneType: SceneType!

    /// Triggered when an individual friend node is tapped, routing the user to the profile view.
    var onFriendTapped: ((Connection) -> Void)?
    
    /// Triggered when the central spiral is tapped, routing the user to the "vacuum" (decayed connections) view.
    var onSpiralTapped: (() -> Void)?

    // State trackers to differentiate between a quick tap and a pan/drag gesture.
    private var touchStartedOnSpiral = false
    private var touchStartLocation: CGPoint?

    /// The active search query — empty means no filter and every connection in `connections` is on stage.
    private var currentFilterText: String = ""

    init(size: CGSize, connections: Set<Connection>, sceneType: SceneType) {
        self.sceneType = sceneType
        super.init(size: size)
        self.connections = connections
        self.backgroundColor = .lightBackground
        self.addChild(rootNode)
        
        if sceneType == .initial {
            initSpiral()
            initFriends()
        }
        initCamera()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func initCamera() {
        let camera = SKCameraNode()
        self.camera = camera
        addChild(camera)
    }

    func initSpiral() {
        let spiral = SKSpriteNode(texture: SKTexture(imageNamed: "Spiral"), size: CGSize(width: 122, height: 122))
        spiral.name = "spiral"
        // The Spiral asset is padded with transparency around the visible drawing, so the physics radius
        // must be smaller than half the sprite size to let friend nodes visually touch the artwork.
        spiral.physicsBody = SKPhysicsBody(circleOfRadius: 42)
        spiral.physicsBody?.affectedByGravity = false
        spiral.physicsBody?.isDynamic = false
        self.rootNode.addChild(spiral)
    }

    func initFriends() {
        for connection in connections {
            addFriendNode(for: connection)
        }
    }

    /// Spawns a physical node for a connection and tethers it to the center using a spring joint.
    private func addFriendNode(for connection: Connection) {
        let friend = FriendNode(connection: connection)
        friend.onTapped = { [weak self] in
            self?.onFriendTapped?(connection)
        }
        
        // Random initial spawn location to prevent nodes from stacking perfectly on top of each other
        var randomX = CGFloat.random(in: -100...100)
        randomX = randomX < 0 ? min(-60, randomX) : max(60, randomX)
        var randomY = CGFloat.random(in: -100...100)
        randomY = randomY < 0 ? min(-60, randomY) : max(60, randomY)

        self.rootNode.addChild(friend)
        
        let springAnchor = SpringNode()
        self.rootNode.addChild(springAnchor)
        
        let spring = SKPhysicsJointSpring.joint(
            withBodyA: friend.physicsBody!,
            bodyB: springAnchor.physicsBody!,
            anchorA: friend.position,
            anchorB: springAnchor.position)
        spring.frequency = 0.8
        spring.damping = 0.5
        self.physicsWorld.add(spring)
        
        friend.position = CGPoint(x: randomX, y: randomY)
    }

    /// Synchronizes the graphical nodes with the current state of the database.
    /// Safely adds new friends or removes deleted ones without rebuilding the entire physics simulation.
    func updateConnections(receivedConnections: Set<Connection>) {
        self.connections = receivedConnections
        syncNodesToVisibleConnections()
    }

    /// The subset of `connections` that should currently be on stage, respecting the active search filter.
    private var visibleConnections: Set<Connection> {
        guard !currentFilterText.isEmpty else { return connections }
        return connections.filter { $0.friend.name.localizedCaseInsensitiveContains(currentFilterText) }
    }

    /// Adds nodes for newly visible connections and removes the ones that fell out of view,
    /// so the physics simulation keeps animating only the relevant subset instead of frozen invisible nodes.
    private func syncNodesToVisibleConnections() {
        let target = visibleConnections
        let targetIDs = Set(target.map { $0.friend.id.uuidString })

        let currentNodes = rootNode.children.compactMap { $0 as? FriendNode }
        let currentIDs = Set(currentNodes.compactMap { $0.name })

        let nodesToRemove = currentNodes.filter { node in
            guard let name = node.name else { return false }
            return !targetIDs.contains(name)
        }
        rootNode.removeChildren(in: nodesToRemove)

        for connection in target where !currentIDs.contains(connection.friend.id.uuidString) {
            addFriendNode(for: connection)
        }
    }

    /// Forces all active nodes to recalculate their size, orbit, and color based on the latest relationship scores.
    func updateNodeVisuals() {
        for child in rootNode.children {
            guard let friendNode = child as? FriendNode else { continue }
            guard let connection = connections.first(where: { $0.friend.id.uuidString == (friendNode.name ?? "") }) else { continue }
            let state = connection.metaManager.currentRelationshipState
            friendNode.score = connection.metaManager.score
            friendNode.setScale(state.nodeSize / 256.0)
            friendNode.sprite.strokeColor = state.color
            friendNode.orbitRadius = state.orbitRadius
            if let image = UIImage(data: connection.friend.profilePicture) {
                friendNode.sprite.fillTexture = SKTexture(image: image.normalized)
            }
        }
    }

    /// Checks whether the given scene-space point lies over the central spiral node.
    /// Allows overlapping friend nodes to forward their touch sequence to the scene so the spiral tap still wins.
    func isTouchOverSpiral(_ sceneLocation: CGPoint) -> Bool {
        nodes(at: sceneLocation).contains { $0.name == "spiral" }
    }

    /// Updates the active search filter and re-synchronizes the visible nodes so the unmatched ones
    /// physically leave the stage instead of remaining as frozen invisible bodies.
    func filterByName(_ text: String) {
        currentFilterText = text
        syncNodesToVisibleConnections()
    }

    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        firstTouch = touch
        let sceneLocation = touch.location(in: self)
        touchStartLocation = sceneLocation
        let location = touch.location(in: self.rootNode)
        let tan = (location.x) / (location.y)
        touchOffset = atan(tan)

        // The scene only receives the touch when no friend node consumed it, or when a friend node
        // explicitly forwarded the sequence because the spiral was sitting beneath the press.
        // In both cases the spiral wins as long as it is in `nodes(at:)`.
        touchStartedOnSpiral = nodes(at: sceneLocation).contains { $0.name == "spiral" }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        
        // Translates linear finger movement into rotational movement for the entire social graph
        let location = touch.location(in: self.rootNode)
        let tan = (location.x) / (location.y)
        let newAngle = atan(tan)
        let deltaAngle = (newAngle - touchOffset)
        self.rootNode.zRotation -= deltaAngle
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }

        // Determine if the interaction was a clean tap or a pan/drag
        if touchStartedOnSpiral, let start = touchStartLocation {
            let end = touch.location(in: self)
            let dx = end.x - start.x
            let dy = end.y - start.y
            if sqrt(dx * dx + dy * dy) < 10 {
                onSpiralTapped?()
            }
        }

        if touch == firstTouch {
            firstTouch = nil
            self.pinchDistance = 0
            self.touchOffset = 0
        } else if touch == secondTouch {
            secondTouch = nil
            self.pinchDistance = 0
        }

        touchStartedOnSpiral = false
        touchStartLocation = nil
    }

    override func update(_ currentTime: TimeInterval) {
        for child in self.rootNode.children {
            if let friend = child as? FriendNode {
                friend.update()
            }
        }
    }
}
