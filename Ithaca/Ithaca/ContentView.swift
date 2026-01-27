//
//  ContentView.swift
//  Ithaca
//
//  Created by Armando Valencia on 1/26/26.
//

import SwiftUI
import AppKit

struct RootView: View {
    @ObservedObject var store: RepoStore
    @ObservedObject var popoverState: PopoverState
    let onRequestClose: () -> Void

    @State private var query: String = ""
    @State private var selectedID: String?
    @State private var errorMessage: String?
    @FocusState private var searchFocused: Bool

    private var displayedRepos: [Repo] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return store.recentRepos()
        }
        return SearchRanker.search(repos: store.repos, query: trimmed)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if store.workspaceRoots.isEmpty {
                setupView
            } else {
                mainView
            }
        }
        .padding(14)
        .frame(width: 420, height: 520, alignment: .top)
        .onChange(of: popoverState.isShown) { _, isShown in
            if isShown {
                searchFocused = true
            }
        }
        .onAppear {
            if selectedID == nil {
                selectedID = displayedRepos.first?.id
            }
        }
        .onChange(of: query) { _, _ in
            errorMessage = nil
        }
        .onChange(of: displayedRepos.map { $0.id }) { _, _ in
            if let selectedID, displayedRepos.contains(where: { $0.id == selectedID }) {
                return
            }
            selectedID = displayedRepos.first?.id
        }
        .onMoveCommand { direction in
            moveSelection(direction)
        }
        .onExitCommand {
            onRequestClose()
        }
    }

    private var setupView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add workspace roots to scan repositories.")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(store.workspaceRoots, id: \.self) { root in
                    HStack(spacing: 8) {
                        Text(root)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button("Remove") {
                            store.removeWorkspaceRoot(root)
                        }
                        .buttonStyle(.link)
                    }
                }
            }

            HStack(spacing: 10) {
                Button("Add Root…") {
                    chooseWorkspaceRoot()
                }
                Button("Scan Repositories") {
                    store.rescan()
                }
                .disabled(store.workspaceRoots.isEmpty)

                Spacer()

                if store.isScanning {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
        }
    }

    private var mainView: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Search repositories…", text: $query)
                .textFieldStyle(.roundedBorder)
                .focused($searchFocused)
                .onSubmit {
                    openSelectedRepo()
                }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            VStack(alignment: .leading, spacing: 8) {
                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Recent")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        if displayedRepos.isEmpty {
                            Text("No repositories found.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(displayedRepos) { repo in
                                RepoRow(
                                    repo: repo,
                                    isSelected: repo.id == selectedID,
                                    onSelect: { selectedID = repo.id },
                                    onOpen: { openRepo(repo) }
                                )
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func moveSelection(_ direction: MoveCommandDirection) {
        guard !displayedRepos.isEmpty else { return }
        guard let currentID = selectedID,
              let currentIndex = displayedRepos.firstIndex(where: { $0.id == currentID }) else {
            selectedID = displayedRepos.first?.id
            return
        }

        switch direction {
        case .down:
            let next = min(currentIndex + 1, displayedRepos.count - 1)
            selectedID = displayedRepos[next].id
        case .up:
            let next = max(currentIndex - 1, 0)
            selectedID = displayedRepos[next].id
        default:
            break
        }
    }

    private func openSelectedRepo() {
        guard let repo = displayedRepos.first(where: { $0.id == selectedID }) else { return }
        openRepo(repo)
    }

    private func openRepo(_ repo: Repo) {
        errorMessage = nil
        Task {
            let result = await VSCodeOpener.open(path: repo.path)
            switch result {
            case .success:
                await MainActor.run {
                    store.markOpened(repoID: repo.id)
                }
            case .failure(let error):
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func chooseWorkspaceRoot() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Add"

        if panel.runModal() == .OK, let url = panel.url {
            store.addWorkspaceRoot(url.path)
        }
    }
}

struct RepoRow: View {
    let repo: Repo
    let isSelected: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(repo.name)
                .font(.callout)
                .foregroundStyle(.primary)
            Text(repo.path)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onTapGesture(count: 2) {
            onOpen()
        }
    }
}

#Preview {
    RootView(store: RepoStore(), popoverState: PopoverState(), onRequestClose: {})
}
