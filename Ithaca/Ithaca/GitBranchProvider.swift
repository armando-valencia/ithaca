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
        guard let head = readTrimmedHead(from: headURL) else { return nil }
        if head.hasPrefix("ref: ") {
            let ref = head.replacingOccurrences(of: "ref: ", with: "")
            return ref.split(separator: "/").last.map(String.init)
        }
        return nil
    }

    private static func resolveGitDir(for repoPath: String) -> URL? {
        let repoURL = URL(fileURLWithPath: repoPath).standardizedFileURL
        let dotGitURL = repoURL.appendingPathComponent(".git")
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: dotGitURL.path, isDirectory: &isDir) {
            if isDir.boolValue {
                return dotGitURL
            }
            if let contents = readTrimmedHead(from: dotGitURL),
               contents.hasPrefix("gitdir: ") {
                let path = contents.replacingOccurrences(of: "gitdir: ", with: "").trimmingCharacters(in: .whitespaces)
                guard !path.isEmpty else { return nil }
                let gitDirURL: URL = path.hasPrefix("/")
                    ? URL(fileURLWithPath: path).standardizedFileURL
                    : repoURL.appendingPathComponent(path).standardizedFileURL
                return isGitDirectory(gitDirURL) ? gitDirURL : nil
            }
        }
        return nil
    }

    private static func isGitDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return false
        }

        var isHeadDirectory: ObjCBool = false
        return FileManager.default.fileExists(
            atPath: url.appendingPathComponent("HEAD").path,
            isDirectory: &isHeadDirectory
        ) && !isHeadDirectory.boolValue
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
