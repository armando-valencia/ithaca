//
//  RepoStore.swift
//  Ithaca
//
//  Created by Armando Valencia on 1/26/26.
//

import Foundation
import Combine

struct RepoStoreIssue: Identifiable, Hashable, Sendable {
    let id: String
    let message: String
}

@MainActor
final class RepoStore: ObservableObject {
    @Published private(set) var repos: [Repo] = []
    @Published private(set) var workspaceRoots: [String] = []
    @Published private(set) var issues: [RepoStoreIssue] = []
    @Published var isScanning: Bool = false
    @Published var defaultOpenTarget: OpenTarget = .vscode
    @Published var showBranches: Bool = true
    private var pendingRescan: Bool = false

    private let rootsKey = "workspaceRoots"
    private let rootsBookmarksKey = "workspaceRootBookmarks"
    private let defaultOpenTargetKey = "defaultOpenTarget"
    private let showBranchesKey = "showBranches"
    private let ignoredDirectories: Set<String> = [
        "node_modules", ".venv", "dist", "build", ".tox", ".pytest_cache",
        ".mypy_cache", ".next", "target", ".gradle"
    ]

    private var workspaceRootBookmarks: [String: Data] = [:]
    private var cacheIssue: RepoStoreIssue?
    private var persistenceIssue: RepoStoreIssue?
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
        loadDefaultOpenTarget()
        loadShowBranches()
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
            let result = RepoStore.scan(roots: roots, ignored: ignoredDirectories, bookmarks: bookmarks)
            let merged = result.repos.map { repo -> Repo in
                if let prior = existing[repo.id] {
                    var updated = repo
                    updated.lastOpened = prior.lastOpened
                    updated.isPinned = prior.isPinned
                    updated.openTarget = prior.openTarget
                    return updated
                }
                return repo
            }
            let sorted = merged.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            await MainActor.run {
                self.repos = sorted
                self.isScanning = false
                self.replaceScanIssues(with: result.issues)
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

    func togglePin(repoID: String) {
        guard let index = repos.firstIndex(where: { $0.id == repoID }) else { return }
        repos[index].isPinned.toggle()
        saveIndex()
    }

    func isPathAllowed(_ path: String) -> Bool {
        let candidate = URL(fileURLWithPath: path).standardizedFileURL.path
        for root in workspaceRoots {
            let rootPath = resolvedWorkspaceRootURL(for: root).path
            if candidate == rootPath || candidate.hasPrefix(rootPath + "/") {
                return true
            }
        }
        return false
    }

    private func resolvedWorkspaceRootURL(for root: String) -> URL {
        guard let data = workspaceRootBookmarks[root] else {
            return URL(fileURLWithPath: root).standardizedFileURL
        }

        var isStale = false
        return (try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ))?.standardizedFileURL ?? URL(fileURLWithPath: root).standardizedFileURL
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

    func pinnedRepos() -> [Repo] {
        repos
            .filter { $0.isPinned }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
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

    private func loadDefaultOpenTarget() {
        guard let raw = UserDefaults.standard.string(forKey: defaultOpenTargetKey),
              let target = OpenTarget(rawValue: raw) else {
            defaultOpenTarget = .vscode
            return
        }
        defaultOpenTarget = target
    }

    func updateDefaultOpenTarget(_ target: OpenTarget) {
        defaultOpenTarget = target
        UserDefaults.standard.set(target.rawValue, forKey: defaultOpenTargetKey)
    }

    func updateShowBranches(_ enabled: Bool) {
        showBranches = enabled
        UserDefaults.standard.set(enabled, forKey: showBranchesKey)
    }

    func resetCache() {
        let url = indexURL()
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            cacheIssue = nil
            updateIssues()
            rescan()
        } catch {
            persistenceIssue = RepoStoreIssue(
                id: "cache-reset",
                message: "Ithaca could not reset its saved repository index: \(error.localizedDescription)"
            )
            updateIssues()
        }
    }

    private func loadShowBranches() {
        if UserDefaults.standard.object(forKey: showBranchesKey) == nil {
            showBranches = true
            return
        }
        showBranches = UserDefaults.standard.bool(forKey: showBranchesKey)
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
        do {
            let data = try Data(contentsOf: url)
            repos = try decoder.decode(RepoIndex.self, from: data).repos
        } catch CocoaError.fileNoSuchFile {
            return
        } catch {
            cacheIssue = RepoStoreIssue(
                id: "cache-load",
                message: "Ithaca could not read its saved repository index. Reset it and rescan your directories."
            )
            updateIssues()
        }
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
            persistenceIssue = nil
            updateIssues()
        } catch {
            persistenceIssue = RepoStoreIssue(
                id: "cache-save",
                message: "Ithaca could not save its repository index: \(error.localizedDescription)"
            )
            updateIssues()
        }
    }

    private func indexURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let directory = base?.appendingPathComponent("Ithaca", isDirectory: true)
        return (directory ?? URL(fileURLWithPath: "/tmp")).appendingPathComponent("index.json")
    }

    private func replaceScanIssues(with scanIssues: [RepoStoreIssue]) {
        issues = ([cacheIssue, persistenceIssue].compactMap { $0 } + scanIssues)
            .reduce(into: [String: RepoStoreIssue]()) { issues, issue in
                issues[issue.id] = issue
            }
            .values
            .sorted { $0.id < $1.id }
    }

    private func updateIssues() {
        replaceScanIssues(with: issues.filter { $0.id.hasPrefix("root-") })
    }

    nonisolated private static func scan(roots: [String], ignored: Set<String>, bookmarks: [String: Data]) -> (repos: [Repo], issues: [RepoStoreIssue]) {
        var results: [Repo] = []
        var issues: [RepoStoreIssue] = []
        var seen: Set<String> = []
        let fileManager = FileManager.default

        for root in roots {
            var rootURL = URL(fileURLWithPath: root)
            var didStartAccessing = false
            if let data = bookmarks[root] {
                var isStale = false
                guard let resolved = try? URL(resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &isStale) else {
                    issues.append(rootIssue(for: root, message: "Ithaca cannot access this directory. Remove it and add it again to restore permission."))
                    continue
                }
                rootURL = resolved
                didStartAccessing = resolved.startAccessingSecurityScopedResource()
                if !didStartAccessing {
                    issues.append(rootIssue(for: root, message: "Ithaca cannot access this directory. Remove it and add it again to restore permission."))
                    continue
                }
            }
            defer {
                if didStartAccessing {
                    rootURL.stopAccessingSecurityScopedResource()
                }
            }

            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: rootURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                issues.append(rootIssue(for: root, message: "The directory is unavailable. Reconnect it or remove it from Ithaca."))
                continue
            }

            let rootGitURL = rootURL.appendingPathComponent(".git")
            var isRootGitDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: rootGitURL.path, isDirectory: &isRootGitDirectory) {
                let repo = Repo(
                    name: rootURL.lastPathComponent,
                    path: rootURL.path
                )
                if seen.insert(repo.id).inserted {
                    results.append(repo)
                }
            }

            guard let enumerator = fileManager.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                issues.append(rootIssue(for: root, message: "Ithaca could not scan this directory. Check its access permission and try again."))
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
                    let repo = Repo(
                        name: repoName,
                        path: url.path
                    )
                    if seen.insert(repo.id).inserted {
                        results.append(repo)
                    }
                    enumerator.skipDescendants()
                }
            }
        }

        return (results, issues)
    }

    nonisolated private static func rootIssue(for root: String, message: String) -> RepoStoreIssue {
        RepoStoreIssue(id: "root-\(root)", message: "\(root): \(message)")
    }
}
