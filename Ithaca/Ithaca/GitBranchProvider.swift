//
//  GitBranchProvider.swift
//  Ithaca
//
//  Created by Armando Valencia on 1/28/26.
//

import Foundation

enum GitBranchProvider {
    static func branch(for path: String) async -> String? {
        guard let gitDir = resolveGitDir(for: path) else { return nil }
        let headURL = gitDir.appendingPathComponent("HEAD")
        guard let head = try? String(contentsOf: headURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines) else {
            return nil
        }
        if head.hasPrefix("ref: ") {
            let ref = head.replacingOccurrences(of: "ref: ", with: "")
            return ref.split(separator: "/").last.map(String.init)
        }
        return nil
    }

    private static func resolveGitDir(for repoPath: String) -> URL? {
        let repoURL = URL(fileURLWithPath: repoPath)
        let dotGitURL = repoURL.appendingPathComponent(".git")
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: dotGitURL.path, isDirectory: &isDir) {
            if isDir.boolValue {
                return dotGitURL
            }
            if let contents = try? String(contentsOf: dotGitURL, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines),
               contents.hasPrefix("gitdir: ") {
                let path = contents.replacingOccurrences(of: "gitdir: ", with: "").trimmingCharacters(in: .whitespaces)
                let gitDirURL: URL
                if path.hasPrefix("/") {
                    gitDirURL = URL(fileURLWithPath: path)
                } else {
                    gitDirURL = repoURL.appendingPathComponent(path)
                }
                return gitDirURL
            }
        }
        return nil
    }
}
