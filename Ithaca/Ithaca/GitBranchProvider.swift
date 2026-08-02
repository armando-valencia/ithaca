//
//  GitBranchProvider.swift
//  Ithaca
//
//  Created by Armando Valencia on 1/28/26.
//

import Foundation

enum GitBranchProvider {
    static func branch(for path: String) async -> String? {
        guard let gitDir = GitRepository.gitDirectory(for: URL(fileURLWithPath: path)) else { return nil }
        let headURL = gitDir.appendingPathComponent("HEAD")
        guard let head = readTrimmedHead(from: headURL) else { return nil }
        if head.hasPrefix("ref: ") {
            let ref = head.replacingOccurrences(of: "ref: ", with: "")
            return ref.split(separator: "/").last.map(String.init)
        }
        return nil
    }

    private static func readTrimmedHead(from url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer {
            try? handle.close()
        }
        let data = (try? handle.read(upToCount: 4096)) ?? Data()
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
