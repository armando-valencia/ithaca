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
    @State private var branchByID: [String: String] = [:]
    @State private var branchLoading: Set<String> = []
    @State private var errorMessage: String?
    @State private var showingSetupOverride: Bool = false
    @State private var showingShortcutHelp: Bool = false
    @State private var showingSettings: Bool = false
    @State private var hasInteracted: Bool = false
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
                hasInteracted = false
                searchFocused = true
                updateBranchesIfNeeded()
            }
        }
        .onChange(of: popoverState.focusRequestID) { _, _ in
            DispatchQueue.main.async {
                searchFocused = true
            }
        }
        .onChange(of: store.showBranches) { _, _ in
            updateBranchesIfNeeded()
        }
        .onAppear {
            if selectedID == nil {
                selectedID = displayedRepos.first?.id
            }
            updateBranchesIfNeeded()
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
            hasInteracted = true
        }
        .onChange(of: displayedRepos.map { $0.id }) { _, _ in
            if let selectedID, displayedRepos.contains(where: { $0.id == selectedID }) {
                return
            }
            selectedID = displayedRepos.first?.id
            updateBranchesIfNeeded()
        }
        .onChange(of: store.repos.map { $0.id }) { _, _ in
            updateBranchesIfNeeded()
        }
        .onChange(of: query) { _, _ in
            updateBranchesIfNeeded()
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
            Text("Add directories to scan repositories.")
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
                Button("Add Directory…") {
                    chooseWorkspaceRoot()
                }
                Button("Rescan") {
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
        VStack(alignment: .leading, spacing: 10) {
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
                Button {
                    showingSettings.toggle()
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingSettings, arrowEdge: .top) {
                    settingsView
                        .frame(width: 360)
                        .padding(12)
                }
            }
            if !hasInteracted {
                Text("↑↓ to navigate · Enter to open")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
            HStack(spacing: 8) {
                Text("Shortcut")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(hotkeyStore.hotkey?.displayString ?? "Off")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.15))
                    )
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
                        Text("Use ⌃⌥⌘I (letter I, not lowercase L).")
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
                            HStack(spacing: 10) {
                                Text("No matches.")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                Button("Rescan") {
                                    store.rescan()
                                }
                                Button("Directories…") {
                                    showingSetupOverride = true
                                }
                                .buttonStyle(.link)
                                Spacer()
                            }
                            .padding(.vertical, 6)
                        } else {
                            if isSearching {
                                ForEach(displayedRepos) { repo in
                                    RepoRow(
                                        repo: repo,
                                        isSelected: repo.id == selectedID,
                                        isHovered: repo.id == hoveredID,
                                        branch: branchByID[repo.id],
                                        showBranch: store.showBranches,
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
                                    sectionHeader("Pinned")
                                }
                                ForEach(pinnedRepos) { repo in
                                    RepoRow(
                                        repo: repo,
                                        isSelected: repo.id == selectedID,
                                        isHovered: repo.id == hoveredID,
                                        branch: branchByID[repo.id],
                                        showBranch: store.showBranches,
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
                                    sectionHeader("Recent")
                                }
                                ForEach(recentRepos) { repo in
                                    RepoRow(
                                        repo: repo,
                                        isSelected: repo.id == selectedID,
                                        isHovered: repo.id == hoveredID,
                                        branch: branchByID[repo.id],
                                        showBranch: store.showBranches,
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
        .animation(.easeOut(duration: 0.2), value: hasInteracted)
    }

    private var settingsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle(isOn: Binding(
                get: { store.showBranches },
                set: { store.updateShowBranches($0) }
            )) {
                Text("Show branches")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .toggleStyle(.switch)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Directories")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(store.workspaceRoots, id: \.self) { root in
                    HStack(spacing: 8) {
                        Text(root)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.secondary.opacity(0.12))
                            )
                        Spacer()
                        Button("Remove") {
                            store.removeWorkspaceRoot(root)
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 10) {
                Button("Add Directory…") {
                    chooseWorkspaceRoot()
                }
                Button("Rescan") {
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

    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 1)
        }
        .padding(.top, 4)
    }

    private func moveSelection(_ direction: MoveCommandDirection) {
        guard !displayedRepos.isEmpty else { return }
        hasInteracted = true
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
        hasInteracted = true
        guard let repo = displayedRepos.first(where: { $0.id == selectedID }) else { return }
        openRepo(repo, targetOverride: nil)
    }

    private func openRepo(_ repo: Repo, targetOverride: OpenTarget?) {
        errorMessage = nil
        guard store.isPathAllowed(repo.path) else {
            errorMessage = "Repository path is outside configured directories."
            return
        }
        Task {
            let target = targetOverride ?? store.defaultOpenTarget
            let result = await OpenTargetOpener.open(target: target, path: repo.path)
            switch result {
            case .success:
                await MainActor.run {
                    store.markOpened(repoID: repo.id)
                    onRequestClose()
                }
            case .failure(let error):
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func updateBranchesIfNeeded() {
        guard store.showBranches else { return }
        for repo in displayedRepos {
            guard branchByID[repo.id] == nil, !branchLoading.contains(repo.id) else { continue }
            branchLoading.insert(repo.id)
            Task {
                let branch = await GitBranchProvider.branch(for: repo.path)
                await MainActor.run {
                    if let branch {
                        branchByID[repo.id] = branch
                    }
                    branchLoading.remove(repo.id)
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
            showingSetupOverride = false
            showingSettings = false
            searchFocused = true
        }
    }

}

struct RepoRow: View {
    let repo: Repo
    let isSelected: Bool
    let isHovered: Bool
    let branch: String?
    let showBranch: Bool
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
                    if isHovered {
                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 6) {
                    Text(displayPath(repo.path))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if showBranch, let branch {
                        Text("• \(branch)")
                            .font(.caption2)
                            .foregroundStyle(Color.secondary.opacity(0.65))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : isHovered ? Color.accentColor.opacity(0.06) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1)
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
