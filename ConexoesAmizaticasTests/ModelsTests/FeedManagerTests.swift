//
//  FeedManagerTests.swift
//  ConexoesAmizaticas
//
//  Created by Jonas Fernando Nascimento Melo on 28/05/26.
//

import Testing
import Foundation
@testable import ConexoesAmizaticas

struct FeedManagerTests {

    @Test("Feed manager inicia vazio")
    func startsEmpty() {
        let feed = FeedManager()
        #expect((feed.posts ?? []).isEmpty)
    }

    @Test("addPost adiciona o post à lista")
    func addPostAppendsPost() {
        let feed = FeedManager()
        let post = Post(images: [Data([0x01])])

        feed.addPost(post)

        #expect((feed.posts ?? []).count == 1)
        #expect((feed.posts ?? []).first?.id == post.id)
    }

    @Test("addPost preserva ordem de inserção")
    func addPostPreservesOrder() {
        let feed = FeedManager()
        let p1 = Post(images: [])
        let p2 = Post(images: [])
        let p3 = Post(images: [])

        feed.addPost(p1)
        feed.addPost(p2)
        feed.addPost(p3)

        #expect((feed.posts ?? []).map(\.id) == [p1.id, p2.id, p3.id])
    }

    @Test("deletePost remove apenas o post com id correspondente")
    func deletePostRemovesById() {
        let feed = FeedManager()
        let p1 = Post(images: [])
        let p2 = Post(images: [])
        feed.addPost(p1)
        feed.addPost(p2)

        feed.deletePost(id: p1.id)

        #expect((feed.posts ?? []).count == 1)
        #expect((feed.posts ?? []).first?.id == p2.id)
    }

    @Test("deletePost com id inexistente não altera a lista")
    func deletePostNonexistentIsNoOp() {
        let feed = FeedManager()
        let p1 = Post(images: [])
        feed.addPost(p1)

        feed.deletePost(id: UUID())

        #expect((feed.posts ?? []).count == 1)
    }
}
