//
//  SearchRanker.swift
//  Ithaca
//
//  Created by Armando Valencia on 1/26/26.
//

import Foundation

enum SearchRanker {
    // Examples:
    // search([Repo(name: "Ithaca", path: "/repos/ithaca")], query: "it") -> prefix match
    // search([Repo(name: "repo-indexer", path: "/repos/repo-indexer")], query: "rdi") -> fuzzy match
    static func search(repos: [Repo], query: String) -> [Repo] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return repos }

        let loweredQuery = trimmed.lowercased()
        let scored = repos.compactMap { repo -> (Repo, Int)? in
            let name = repo.name.lowercased()
            guard let score = score(name: name, query: loweredQuery) else { return nil }
            return (repo, score)
        }

        return scored
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                let lhsDate = lhs.0.lastOpened ?? .distantPast
                let rhsDate = rhs.0.lastOpened ?? .distantPast
                if lhsDate != rhsDate { return lhsDate > rhsDate }
                return lhs.0.name.localizedCaseInsensitiveCompare(rhs.0.name) == .orderedAscending
            }
            .map { $0.0 }
    }

    private static func score(name: String, query: String) -> Int? {
        if name.hasPrefix(query) {
            return 300 + (query.count * 2) - name.count
        }
        if name.contains(query) {
            return 200 + query.count - name.count
        }
        if fuzzyMatch(name: name, query: query) {
            return 100 + query.count - name.count
        }
        return nil
    }

    private static func fuzzyMatch(name: String, query: String) -> Bool {
        var nameIndex = name.startIndex
        var queryIndex = query.startIndex

        while nameIndex < name.endIndex && queryIndex < query.endIndex {
            if name[nameIndex] == query[queryIndex] {
                query.formIndex(after: &queryIndex)
            }
            name.formIndex(after: &nameIndex)
        }

        return queryIndex == query.endIndex
    }
}
