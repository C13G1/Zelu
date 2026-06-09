//
//  MessageFramer.swift
//  ConexoesAmizaticas
//
//  Created by Enzo Ferroni on 09/06/26.
//
//  Length-prefixed message framing for an L2CAP byte stream.
//
//  An L2CAP channel is a raw byte pipe with no message boundaries, so several messages sent in a row
//  arrive glued together. Each message is wrapped as [4-byte big-endian length][1-byte type][body].
//  `MessageFramer` hides that bookkeeping: build outgoing frames with `frame(_:body:)`, feed received
//  bytes with `append(_:)`, and pull whole incoming messages with `next()`.
//

import Foundation

struct MessageFramer {
    /// Bytes received but not yet split into whole messages.
    private var buffer = Data()
    /// Largest message we accept; anything bigger means the stream is corrupt.
    private let maxMessageBytes: Int

    init(maxMessageBytes: Int = 2_000_000) {
        self.maxMessageBytes = maxMessageBytes
    }

    /// Signals a corrupt stream — the caller should drop the link.
    enum FramingError: Error { case corrupt }

    /// Wraps a message for sending: [4-byte length][type][body].
    static func frame(_ type: UInt8, body: Data = Data()) -> Data {
        var length = UInt32(1 + body.count).bigEndian
        var out = Data(bytes: &length, count: 4)
        out.append(type)
        out.append(body)
        return out
    }

    /// Adds freshly received bytes to the buffer.
    mutating func append(_ data: Data) {
        buffer.append(data)
    }

    /// Pops the next complete message, or nil if one hasn't fully arrived yet.
    /// - Throws: `FramingError.corrupt` when the framing is invalid.
    mutating func next() throws -> (type: UInt8, body: Data)? {
        guard buffer.count >= 4 else { return nil }
        let start = buffer.startIndex
        let length = (Int(buffer[start]) << 24) | (Int(buffer[start + 1]) << 16)
                   | (Int(buffer[start + 2]) << 8) | Int(buffer[start + 3])
        guard length >= 1, length <= maxMessageBytes else { throw FramingError.corrupt }
        guard buffer.count >= length + 4 else { return nil }

        let type = buffer[start + 4]
        let body = buffer.subdata(in: start + 5 ..< start + 4 + length)
        buffer.removeSubrange(start ..< start + 4 + length)
        return (type, body)
    }
}
