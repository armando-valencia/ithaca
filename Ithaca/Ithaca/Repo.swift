//
//  Repo.swift
//  Ithaca
//
//  Created by Armando Valencia on 1/26/26.
//

import Foundation
import CryptoKit

nonisolated struct Repo: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var name: String
    var path: String
    var lastOpened: Date?

    init(name: String, path: String, lastOpened: Date? = nil) {
        self.name = name
        self.path = path
        self.lastOpened = lastOpened
        self.id = Repo.stableID(for: path)
    }

    static func stableID(for path: String) -> String {
        let data = Data(path.utf8)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

nonisolated struct RepoIndex: Codable, Sendable {
    var repos: [Repo]
}
