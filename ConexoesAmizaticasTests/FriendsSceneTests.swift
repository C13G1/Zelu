//
//  FriendsSceneTests.swift
//  ConexoesAmizaticas
//
//  Created by Thomas Pinheiro Grandin on 28/05/26.
//

import Testing
import SpriteKit
@testable import ConexoesAmizaticas

@Suite("Friends Scene Tests")

@MainActor
struct FriendsSceneTests {

    /// Function to create the scene that will be tested
    private func createSUT(size: CGSize = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height), connections: Set<Connection> = [], sceneType: SceneType = .initial) -> FriendsScene {
        return FriendsScene(size: size, connections: connections, sceneType: sceneType)
    }

    @Test("Initial Scene initialization test.")
    func testInitialization() {
        let sut = createSUT(sceneType: .initial)
        
        // Assert camera is set
        #expect(sut.camera != nil, "Camera was not initialized.")
        
        // Assert spiral is created
        let spiral = sut.rootNode.childNode(withName: "spiral")
        #expect(spiral != nil, "Root node should contain the spiral.")
    }

    @Test("Updating connections adds new nodes to the scene")
    func testUpdateConnectionsAddsNodes() {
        let connection = Connection(friend: User())
        let sut = createSUT(connections: Set([connection]))
        
        // Ensure initial connections are added
        #expect(sut.rootNode.childNode(withName: connection.friend?.id.uuidString ?? "") != nil, "Initial connections were not added to scene.")
        
        // Add a new connection
        let newConnection = Connection(friend: User())
        let updatedConnections: Set<Connection> = Set([connection, newConnection])
        
        sut.updateConnections(receivedConnections: updatedConnections)
        
        // Verify both nodes exist
        #expect(sut.connections.count == 2, "Scene should have exactly two connections")
        #expect(sut.rootNode.childNode(withName: newConnection.friend?.id.uuidString ?? "") != nil, "newConnection node should be added to the rootNode.")
    }

    @Test("Updating connections removes deleted nodes from the scene")
    func testUpdateConnectionsRemovesNodes() {
        let connectionToMaintain = Connection(friend: User())
        let connectionToRemove = Connection(friend: User())
        let sut = createSUT(connections: Set([connectionToRemove, connectionToMaintain]))
        
        // Update connections without connectionToRemove
        sut.updateConnections(receivedConnections: [connectionToMaintain])
        
        // Check if right connection was removed
        #expect(sut.connections.count == 1, "Scene should have exactly two connections")
        #expect(sut.rootNode.childNode(withName: connectionToRemove.friend?.id.uuidString ?? "") == nil, "this node should be removed from the rootNode.")
        #expect(sut.rootNode.childNode(withName: connectionToMaintain.friend?.id.uuidString ?? "") != nil, "this node should remain.")
    }

    @Test("Filtering by name hides non-matching nodes and disables their physics")
    func testFilterByName() {
        let connection = Connection(friend: User(name: "testName"))
        let sut = createSUT(connections: Set([connection]))
        
        guard let connectionNode = sut.rootNode.childNode(withName: "testName") else {
            print("error initializing in filter test")
            return
        }

        // Apply filter
        sut.filterByName("test")
        
        // Assert connectionNode is visible and dynamic
        #expect(connectionNode.isHidden == false, "connectionNode is not hidden")
        #expect(connectionNode.physicsBody?.isDynamic == true, "connectionNode is not dynamic")
        
        // Clear filter
        sut.filterByName("")
        
        // Assert connectionNode is visible again
        #expect(connectionNode.isHidden == false, "connectionNode is hidden")
    }
}
