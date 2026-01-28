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
    @ObservedObject var hotkeyStore: HotkeyStore
    let onRequestClose: () -> Void

    @State private var query: String = ""
    @State private var selectedID: String?
    @State private var hoveredID: String?
    @State private var errorMessage: String?
    @State private var showingSetupOverride: Bool = false
    @State private var showingShortcutHelp: Bool = false
    @FocusState private var searchFocused: Bool
    @State private var keyMonitor: Any?

    private var displayedRepos: [Repo] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            let pinned = store.pinnedRepos()
            let recents = store.recentRepos().filter { !$0.isPinned }
            return pinned + recents
        }
        let pinned = SearchRanker.search(repos: store.repos.filter { $0.isPinned }, query: trimmed)
        let others = SearchRanker.search(repos: store.repos.filter { !$0.isPinned }, query: trimmed)
        return pinned + others
    }

    private var pinnedRepos: [Repo] {
        store.pinnedRepos()
    }

    private var recentRepos: [Repo] {
        store.recentRepos().filter { !$0.isPinned }
    }

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if store.workspaceRoots.isEmpty || showingSetupOverride {
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
            if keyMonitor == nil {
                keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    switch event.keyCode {
                    case 126:
                        moveSelection(.up)
                        return nil
                    case 125:
                        moveSelection(.down)
                        return nil
                    case 53:
                        onRequestClose()
                        return nil
                    default:
                        return event
                    }
                }
            }
        }
        .onDisappear {
            if let keyMonitor {
                NSEvent.removeMonitor(keyMonitor)
                self.keyMonitor = nil
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
            if !store.workspaceRoots.isEmpty {
                HStack {
                    Spacer()
                    Button("Done") {
                        showingSetupOverride = false
                    }
                    .buttonStyle(.link)
                }
            }
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
                        .controlSize(.small)
                        .frame(width: 16, height: 16)
                }
            }
        }
    }

    private var mainView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                TextField("Search repositories…", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .focused($searchFocused)
                    .onSubmit {
                        openSelectedRepo()
                    }
                Menu {
                    Picker("Default Open", selection: Binding(
                        get: { store.defaultOpenTarget },
                        set: { store.updateDefaultOpenTarget($0) }
                    )) {
                        ForEach(OpenTarget.allCases) { target in
                            Text(target.displayName).tag(target)
                        }
                    }
                } label: {
                    Text(store.defaultOpenTarget.displayName)
                }
                .menuStyle(.borderlessButton)
                Button("Roots…") {
                    showingSetupOverride = true
                }
                .buttonStyle(.link)
            }
            HStack(spacing: 8) {
                Text("Shortcut:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(hotkeyStore.hotkey?.displayString ?? "Off")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                Button {
                    showingShortcutHelp.toggle()
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingShortcutHelp, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Global Shortcut")
                            .font(.callout)
                        Text("Use control (⌃) + option (⌥) + command (⌘) + I.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                }
                Spacer()
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            VStack(alignment: .leading, spacing: 8) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        if displayedRepos.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("No repositories found.")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 12) {
                                    Button("Scan Repositories") {
                                        store.rescan()
                                    }
                                    Button("Manage Roots…") {
                                        showingSetupOverride = true
                                    }
                                    .buttonStyle(.link)
                                }
                            }
                            .padding(.vertical, 8)
                        } else {
                            if isSearching {
                                ForEach(displayedRepos) { repo in
                                    RepoRow(
                                        repo: repo,
                                        isSelected: repo.id == selectedID,
                                        isHovered: repo.id == hoveredID,
                                        onSelect: { selectedID = repo.id },
                                    onOpen: { openRepo(repo, targetOverride: nil) },
                                        onHover: { isHovering in
                                            hoveredID = isHovering ? repo.id : (hoveredID == repo.id ? nil : hoveredID)
                                        },
                                    onTogglePin: { store.togglePin(repoID: repo.id) },
                                    onOpenWith: { target in openRepo(repo, targetOverride: target) }
                                )
                            }
                            } else {
                                if !pinnedRepos.isEmpty {
                                    Text("Pinned")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                ForEach(pinnedRepos) { repo in
                                    RepoRow(
                                        repo: repo,
                                        isSelected: repo.id == selectedID,
                                        isHovered: repo.id == hoveredID,
                                        onSelect: { selectedID = repo.id },
                                        onOpen: { openRepo(repo, targetOverride: nil) },
                                        onHover: { isHovering in
                                            hoveredID = isHovering ? repo.id : (hoveredID == repo.id ? nil : hoveredID)
                                        },
                                        onTogglePin: { store.togglePin(repoID: repo.id) },
                                        onOpenWith: { target in openRepo(repo, targetOverride: target) }
                                    )
                                }
                                if !recentRepos.isEmpty {
                                    Text("Recent")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                ForEach(recentRepos) { repo in
                                    RepoRow(
                                        repo: repo,
                                        isSelected: repo.id == selectedID,
                                        isHovered: repo.id == hoveredID,
                                        onSelect: { selectedID = repo.id },
                                        onOpen: { openRepo(repo, targetOverride: nil) },
                                        onHover: { isHovering in
                                            hoveredID = isHovering ? repo.id : (hoveredID == repo.id ? nil : hoveredID)
                                        },
                                        onTogglePin: { store.togglePin(repoID: repo.id) },
                                        onOpenWith: { target in openRepo(repo, targetOverride: target) }
                                    )
                                }
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
        openRepo(repo, targetOverride: nil)
    }

    private func openRepo(_ repo: Repo, targetOverride: OpenTarget?) {
        errorMessage = nil
        Task {
            let target = targetOverride ?? store.defaultOpenTarget
            let result = await OpenTargetOpener.open(target: target, path: repo.path)
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
    let isHovered: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void
    let onHover: (Bool) -> Void
    let onTogglePin: () -> Void
    let onOpenWith: (OpenTarget?) -> Void

    var body: some View {
        Button(action: {
            onSelect()
            onOpen()
        }) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(repo.name)
                        .font(.callout)
                        .foregroundStyle(.primary)
                    if repo.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                Text(displayPath(repo.path))
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
                    .fill((isSelected || isHovered) ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering in
            onHover(isHovering)
        }
        .contextMenu {
            Button(repo.isPinned ? "Unpin" : "Pin") {
                onTogglePin()
            }
            Menu("Open With") {
                Button("Use Default") {
                    onOpenWith(nil)
                }
                ForEach(OpenTarget.allCases) { target in
                    Button(target.displayName) {
                        onOpenWith(target)
                    }
                }
            }
        }
    }

    private func displayPath(_ path: String) -> String {
        let homeDirectory = NSHomeDirectory()
        let userHome = "/Users/\(NSUserName())"
        let candidates = [homeDirectory, userHome]

        for candidate in candidates {
            if path == candidate {
                return "~"
            }
            if path.hasPrefix(candidate + "/") {
                let suffix = path.dropFirst(candidate.count)
                return "~" + suffix
            }
        }
        return path
    }
}

#Preview {
    RootView(store: RepoStore(), popoverState: PopoverState(), hotkeyStore: HotkeyStore(), onRequestClose: {})
}
