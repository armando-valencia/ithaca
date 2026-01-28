//
//  RepoStore.swift
//  Ithaca
//
//  Created by Armando Valencia on 1/26/26.
//

import Foundation
import Combine

@MainActor
final class RepoStore: ObservableObject {
    @Published private(set) var repos: [Repo] = []
    @Published private(set) var workspaceRoots: [String] = []
    @Published var isScanning: Bool = false
    private var pendingRescan: Bool = false

    private let rootsKey = "workspaceRoots"
    private let rootsBookmarksKey = "workspaceRootBookmarks"
    private let ignoredDirectories: Set<String> = [
        "node_modules", ".venv", "dist", "build", ".tox", ".pytest_cache",
        ".mypy_cache", ".next", "target", ".gradle"
    ]

    private var workspaceRootBookmarks: [String: Data] = [:]
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        loadWorkspaceRoots()
        loadWorkspaceRootBookmarks()
        refreshWorkspaceRootBookmarks()
        loadCache()
    }

    func loadCacheAndRescan() {
        loadCache()
        guard !workspaceRoots.isEmpty else { return }
        rescan()
    }

    func addWorkspaceRoot(_ path: String) {
        guard !workspaceRoots.contains(path) else { return }
        workspaceRoots.append(path)
        saveWorkspaceRoots()
        storeBookmark(for: path)
        rescan()
    }

    func removeWorkspaceRoot(_ path: String) {
        workspaceRoots.removeAll { $0 == path }
        saveWorkspaceRoots()
        workspaceRootBookmarks.removeValue(forKey: path)
        saveWorkspaceRootBookmarks()
        rescan()
    }

    func rescan() {
        guard !isScanning else {
            pendingRescan = true
            return
        }
        guard !workspaceRoots.isEmpty else {
            repos = []
            saveIndex()
            return
        }

        isScanning = true
        let roots = workspaceRoots
        let existing = Dictionary(uniqueKeysWithValues: repos.map { ($0.id, $0) })
        let bookmarks = workspaceRootBookmarks

        Task.detached(priority: .background) { [ignoredDirectories] in
            let scanned = RepoStore.scan(roots: roots, ignored: ignoredDirectories, bookmarks: bookmarks)
            let merged = scanned.map { repo -> Repo in
                if let prior = existing[repo.id] {
                    var updated = repo
                    updated.lastOpened = prior.lastOpened
                    return updated
                }
                return repo
            }
            let sorted = merged.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            await MainActor.run {
                self.repos = sorted
                self.isScanning = false
                self.saveIndex()
                if self.pendingRescan {
                    self.pendingRescan = false
                    self.rescan()
                }
            }
        }
    }

    func markOpened(repoID: String) {
        guard let index = repos.firstIndex(where: { $0.id == repoID }) else { return }
        repos[index].lastOpened = Date()
        saveIndex()
    }

    func recentRepos() -> [Repo] {
        repos
            .compactMap { $0.lastOpened == nil ? nil : $0 }
            .sorted {
                if let lhs = $0.lastOpened, let rhs = $1.lastOpened {
                    if lhs != rhs { return lhs > rhs }
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            .prefix(12)
            .map { $0 }
    }

    private func loadWorkspaceRoots() {
        let roots = UserDefaults.standard.stringArray(forKey: rootsKey) ?? []
        workspaceRoots = roots.filter { !$0.isEmpty }
    }

    private func loadWorkspaceRootBookmarks() {
        guard let raw = UserDefaults.standard.dictionary(forKey: rootsBookmarksKey) else { return }
        var bookmarks: [String: Data] = [:]
        for (key, value) in raw {
            if let data = value as? Data {
                bookmarks[key] = data
            }
        }
        workspaceRootBookmarks = bookmarks
    }

    private func saveWorkspaceRoots() {
        UserDefaults.standard.set(workspaceRoots, forKey: rootsKey)
    }

    private func saveWorkspaceRootBookmarks() {
        UserDefaults.standard.set(workspaceRootBookmarks, forKey: rootsBookmarksKey)
    }

    private func storeBookmark(for path: String) {
        let url = URL(fileURLWithPath: path)
        do {
            let data = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
            workspaceRootBookmarks[path] = data
            saveWorkspaceRootBookmarks()
        } catch {
            // If bookmark creation fails, keep path-only access.
        }
    }

    private func refreshWorkspaceRootBookmarks() {
        var updated: [String: Data] = workspaceRootBookmarks
        var didUpdate = false

        for root in workspaceRoots {
            guard let data = workspaceRootBookmarks[root] else { continue }
            var isStale = false
            guard let resolved = try? URL(resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &isStale) else {
                continue
            }

            if isStale {
                let didStartAccessing = resolved.startAccessingSecurityScopedResource()
                defer {
                    if didStartAccessing {
                        resolved.stopAccessingSecurityScopedResource()
                    }
                }
                if let refreshed = try? resolved.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil) {
                    updated[root] = refreshed
                    didUpdate = true
                }
            }
        }

        if didUpdate {
            workspaceRootBookmarks = updated
            saveWorkspaceRootBookmarks()
        }
    }

    private func loadCache() {
        let url = indexURL()
        guard let data = try? Data(contentsOf: url) else { return }
        guard let index = try? decoder.decode(RepoIndex.self, from: data) else { return }
        repos = index.repos
    }

    private func saveIndex() {
        let url = indexURL()
        let directory = url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try encoder.encode(RepoIndex(repos: repos))
            let tempURL = directory.appendingPathComponent("index.json.tmp")
            try data.write(to: tempURL, options: .atomic)
            if FileManager.default.fileExists(atPath: url.path) {
                _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
            } else {
                try FileManager.default.moveItem(at: tempURL, to: url)
            }
        } catch {
            // Ignore persistence errors to avoid blocking UI.
        }
    }

    private func indexURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let directory = base?.appendingPathComponent("Ithaca", isDirectory: true)
        return (directory ?? URL(fileURLWithPath: "/tmp")).appendingPathComponent("index.json")
    }

    nonisolated private static func scan(roots: [String], ignored: Set<String>, bookmarks: [String: Data]) -> [Repo] {
        var results: [Repo] = []
        var seen: Set<String> = []
        let fileManager = FileManager.default

        for root in roots {
            var rootURL = URL(fileURLWithPath: root)
            var didStartAccessing = false
            if let data = bookmarks[root] {
                var isStale = false
                if let resolved = try? URL(resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &isStale) {
                    rootURL = resolved
                    didStartAccessing = resolved.startAccessingSecurityScopedResource()
                }
            }
            defer {
                if didStartAccessing {
                    rootURL.stopAccessingSecurityScopedResource()
                }
            }

            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: rootURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                continue
            }

            let rootGitURL = rootURL.appendingPathComponent(".git")
            var isRootGitDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: rootGitURL.path, isDirectory: &isRootGitDirectory) {
                let repo = Repo(name: rootURL.lastPathComponent, path: rootURL.path)
                if seen.insert(repo.id).inserted {
                    results.append(repo)
                }
            }

            guard let enumerator = fileManager.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                continue
            }

            for case let url as URL in enumerator {
                let name = url.lastPathComponent
                if ignored.contains(name) {
                    enumerator.skipDescendants()
                    continue
                }

                let gitURL = url.appendingPathComponent(".git")
                var isGitDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: gitURL.path, isDirectory: &isGitDirectory) {
                    let repoName = url.lastPathComponent
                    let repo = Repo(name: repoName, path: url.path)
                    if seen.insert(repo.id).inserted {
                        results.append(repo)
                    }
                    enumerator.skipDescendants()
                }
            }
        }

        return results
    }
}
