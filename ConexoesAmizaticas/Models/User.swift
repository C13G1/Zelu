//
//  User.swift
//  ConexoesAmizaticas
//
//  Created by Thomas Pinheiro Grandin on 18/05/26.
//

import SwiftData
import SwiftUI

/// Represents a user profile within the application context.
///
/// This model conforms to `Codable` to facilitate serialization, primarily for transferring
/// profile information to nearby peers over Bluetooth via the `BLEManager`.
@Model
class User: Codable {
    private(set) var name:           String = "DefaultName"
    private(set) var profilePicture: Data = Data()
    private(set) var id:             UUID = UUID()

    /// `true` only for this account's own profile. Synced via CloudKit so every device agrees on who the
    /// owner is, independent of import order. Deliberately NOT in `CodingKeys`: a profile received over BLE
    /// is always a friend, so it must never arrive flagged as owner.
    var isOwner: Bool = false

    /// Inverse of `Connection.friend`, required by CloudKit. Not serialized over BLE.
    var connection: Connection?

    /// The account owner: the single profile flagged `isOwner`. If more than one exists (e.g. onboarded on
    /// two devices before they synced), the lowest id wins so every device resolves the same owner.
    static func owner(in users: [User]) -> User? {
        let owners = users.filter(\.isOwner)
        if owners.count <= 1 { return owners.first }
        return owners.min { $0.id.uuidString < $1.id.uuidString }
    }

    init(
        name: String = "DefaultName",
        profilePicture: Data = UIImage(named: "defaultPicture")?.jpegData(compressionQuality: 1) ?? Data(),
        id: UUID = UUID()
    ) {
        self.name           = name
        self.profilePicture = profilePicture
        self.id             = id
    }

    required init(from decoder: any Decoder) throws {
        let container       = try decoder.container(keyedBy: CodingKeys.self)
        self.name           = try container.decode(String.self, forKey: .name)
        self.profilePicture = try container.decode(Data.self, forKey: .profilePicture)
        self.id             = try container.decode(UUID.self, forKey: .id)
    }

    /// Updates the user's display name.
    func editName(_ name: String) {
        self.name = name
    }

    /// Updates the user's avatar image.
    func editProfileImageData(_ image: Data) {
        self.profilePicture = image
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(profilePicture, forKey: .profilePicture)
        try container.encode(id, forKey: .id)
    }

    func getProfileImageData() -> Data { return profilePicture }
    func getName() -> String { return name }
    func getID() -> UUID { return id }

    /// The set of properties serialized when the model is encoded or decoded.
    private enum CodingKeys: String, CodingKey {
        case name
        case profilePicture
        case id
    }
}
