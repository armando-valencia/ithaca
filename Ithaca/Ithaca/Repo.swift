//
//  Repo.swift
//  Ithaca
//
//  Created by Armando Valencia on 1/26/26.
//

import Foundation
import CryptoKit

enum OpenTarget: String, Codable, CaseIterable, Identifiable, Sendable {
    case vscode
    case xcode
    case finder

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vscode:
            return "Visual Studio Code"
        case .xcode:
            return "Xcode"
        case .finder:
            return "Finder"
        }
    }
}

nonisolated struct Repo: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var name: String
    var path: String
    var lastOpened: Date?
    var isPinned: Bool
    var openTarget: OpenTarget?
    var rootPath: String?
    var rootName: String?

    init(
        name: String,
        path: String,
        lastOpened: Date? = nil,
        isPinned: Bool = false,
        openTarget: OpenTarget? = nil,
        rootPath: String? = nil,
        rootName: String? = nil
    ) {
        self.name = name
        self.path = path
        self.lastOpened = lastOpened
        self.isPinned = isPinned
        self.openTarget = openTarget
        self.rootPath = rootPath
        self.rootName = rootName
        self.id = Repo.stableID(for: path)
    }

    static func stableID(for path: String) -> String {
        let data = Data(path.utf8)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case path
        case lastOpened
        case isPinned
        case openTarget
        case rootPath
        case rootName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let path = try container.decode(String.self, forKey: .path)
        self.name = (try? container.decode(String.self, forKey: .name)) ?? URL(fileURLWithPath: path).lastPathComponent
        self.path = path
        self.id = (try? container.decode(String.self, forKey: .id)) ?? Repo.stableID(for: path)
        self.lastOpened = try container.decodeIfPresent(Date.self, forKey: .lastOpened)
        self.isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        self.openTarget = try container.decodeIfPresent(OpenTarget.self, forKey: .openTarget)
        self.rootPath = try container.decodeIfPresent(String.self, forKey: .rootPath)
        self.rootName = try container.decodeIfPresent(String.self, forKey: .rootName)
    }
}

nonisolated struct RepoIndex: Codable, Sendable {
    var repos: [Repo]
}
