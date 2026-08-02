//
//  IthacaTests.swift
//  IthacaTests
//
//  Created by Armando Valencia on 8/2/26.
//

import XCTest
@testable import Ithaca

final class IthacaTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testStableIDIsDeterministic() {
        XCTAssertEqual(Repo.stableID(for: "/repos/ithaca"), Repo.stableID(for: "/repos/ithaca"))
        XCTAssertNotEqual(Repo.stableID(for: "/repos/ithaca"), Repo.stableID(for: "/repos/odyssey"))
    }

    func testRepoDecodingSuppliesMissingLegacyValues() throws {
        let data = Data("{\"path\":\"/repos/ithaca\"}".utf8)
        let repo = try JSONDecoder().decode(Repo.self, from: data)

        XCTAssertEqual(repo.name, "ithaca")
        XCTAssertEqual(repo.id, Repo.stableID(for: "/repos/ithaca"))
        XCTAssertFalse(repo.isPinned)
        XCTAssertNil(repo.openTarget)
    }

    func testSearchRanksPrefixBeforeContainsAndFuzzyMatches() {
        let repos = [
            Repo(name: "my-ithaca-tools", path: "/repos/contains"),
            Repo(name: "Ithaca", path: "/repos/prefix"),
            Repo(name: "indexer-tool", path: "/repos/fuzzy")
        ]

        XCTAssertEqual(SearchRanker.search(repos: repos, query: "it").map(\.name), ["Ithaca", "my-ithaca-tools", "indexer-tool"])
    }

    func testScannerFindsNormalRepositoriesAndLinkedWorktrees() async throws {
        let normalRepository = temporaryDirectory.appendingPathComponent("normal")
        try createRepository(at: normalRepository)

        let worktree = temporaryDirectory.appendingPathComponent("worktree")
        let metadata = temporaryDirectory.appendingPathComponent("metadata")
        try FileManager.default.createDirectory(at: worktree, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: metadata, withIntermediateDirectories: true)
        try "ref: refs/heads/feature\n".write(to: metadata.appendingPathComponent("HEAD"), atomically: true, encoding: .utf8)
        try "gitdir: \(metadata.path)\n".write(to: worktree.appendingPathComponent(".git"), atomically: true, encoding: .utf8)

        let result = RepoStore.scan(roots: [temporaryDirectory.path], ignored: [], bookmarks: [:])
        let branch = await GitBranchProvider.branch(for: worktree.path)

        XCTAssertEqual(Set(result.repos.map(\.name)), ["normal", "worktree"])
        XCTAssertEqual(branch, "feature")
    }

    func testScannerRejectsMalformedGitMarkersAndSkipsHiddenAndIgnoredDirectories() throws {
        let malformedRepository = temporaryDirectory.appendingPathComponent("malformed")
        try FileManager.default.createDirectory(at: malformedRepository, withIntermediateDirectories: true)
        try "gitdir: /does/not/exist\n".write(to: malformedRepository.appendingPathComponent(".git"), atomically: true, encoding: .utf8)

        try createRepository(at: temporaryDirectory.appendingPathComponent(".hidden/repository"))
        try createRepository(at: temporaryDirectory.appendingPathComponent("node_modules/repository"))

        let bareRepository = temporaryDirectory.appendingPathComponent("bare")
        try FileManager.default.createDirectory(at: bareRepository, withIntermediateDirectories: true)
        try "ref: refs/heads/main\n".write(to: bareRepository.appendingPathComponent("HEAD"), atomically: true, encoding: .utf8)

        let result = RepoStore.scan(
            roots: [temporaryDirectory.path],
            ignored: ["node_modules"],
            bookmarks: [:]
        )

        XCTAssertTrue(result.repos.isEmpty)
    }

    func testProcessRunnerCompletesForNoisyCommand() async {
        let result = await ProcessRunner.run(
            executable: "/bin/sh",
            arguments: ["-c", "yes | head -c 100000"]
        )

        XCTAssertEqual(result.exitCode, 0)
    }

    private func createRepository(at url: URL) throws {
        let gitDirectory = url.appendingPathComponent(".git", isDirectory: true)
        try FileManager.default.createDirectory(at: gitDirectory, withIntermediateDirectories: true)
        try "ref: refs/heads/main\n".write(to: gitDirectory.appendingPathComponent("HEAD"), atomically: true, encoding: .utf8)
    }
}
