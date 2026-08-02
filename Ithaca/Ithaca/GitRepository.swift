//
//  GitRepository.swift
//  Ithaca
//
//  Created by Armando Valencia on 8/2/26.
//

import Foundation

enum GitRepository {
    nonisolated static func isRepository(at url: URL) -> Bool {
        gitDirectory(for: url) != nil
    }

    nonisolated static func gitDirectory(for repositoryURL: URL) -> URL? {
        let dotGitURL = repositoryURL.standardizedFileURL.appendingPathComponent(".git")
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: dotGitURL.path, isDirectory: &isDirectory) else {
            return nil
        }

        if isDirectory.boolValue {
            return isGitDirectory(dotGitURL) ? dotGitURL : nil
        }

        guard let contents = readTrimmedText(from: dotGitURL), contents.hasPrefix("gitdir: ") else {
            return nil
        }

        let path = contents
            .dropFirst("gitdir: ".count)
            .trimmingCharacters(in: .whitespaces)
        guard !path.isEmpty else { return nil }

        let gitDirectoryURL: URL
        if path.hasPrefix("/") {
            gitDirectoryURL = URL(fileURLWithPath: path)
        } else {
            gitDirectoryURL = repositoryURL.appendingPathComponent(path)
        }
        let standardizedURL = gitDirectoryURL.standardizedFileURL
        return isGitDirectory(standardizedURL) ? standardizedURL : nil
    }

    nonisolated private static func isGitDirectory(_ url: URL) -> Bool {
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

    nonisolated private static func readTrimmedText(from url: URL) -> String? {
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
