//
//  L2CAPMessageFramer.swift
//  ConexoesAmizaticas
//
//  Created by Enzo Ferroni on 09/06/26.
//

import Foundation

/// Splits a raw L2CAP byte stream into whole messages, and frames outgoing ones.
///
/// An L2CAP channel is a continuous stream of bytes with no message boundaries, so messages sent one
/// after another arrive glued together and can be split across reads. Each message is prefixed with a
/// 4-byte length so the receiver knows where one ends and the next begins.
struct L2CAPMessageFramer {
    private var buffer = Data()
    private let maxMessageBytes: Int

    init(maxMessageBytes: Int = 2_000_000) {
        self.maxMessageBytes = maxMessageBytes
    }

    enum FramingError: Error { case corrupt }

    /// Wraps a message for sending: a 4-byte length followed by the type byte and the body.
    static func frame(_ type: UInt8, body: Data = Data()) -> Data {
        var length = UInt32(1 + body.count).bigEndian
        var out = Data(bytes: &length, count: 4)
        out.append(type)
        out.append(body)
        return out
    }

    /// Adds bytes just read from the stream to the buffer.
    mutating func append(_ data: Data) {
        buffer.append(data)
    }

    /// Returns the next complete message, or nil if it hasn't fully arrived yet.
    /// Throws `FramingError.corrupt` when the length header is invalid (the stream is out of sync).
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
