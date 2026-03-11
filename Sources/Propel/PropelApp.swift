import SwiftUI
import UniformTypeIdentifiers

@main
struct PropelApp: App {
    @State private var boardViewModel = BoardViewModel()
    @State private var notesViewModel = NotesViewModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(boardViewModel)
                .environment(notesViewModel)
                .preferredColorScheme(.dark)
                .frame(minWidth: 800, minHeight: 500)
                .onAppear {
                    appDelegate.boardViewModel = boardViewModel
                }
        }
        .defaultSize(width: 1_200, height: 700)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Propel") {
                    NSApp.activate(ignoringOtherApps: true)
                    openAboutWindow()
                }
            }

            CommandGroup(after: .newItem) {
                Divider()

                Button("Import Board...") {
                    importBoard()
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])

                Button("Export Board...") {
                    exportBoard()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])

                Divider()

                Button("Change Storage Folder...") {
                    changeStorageFolder()
                }

                Button("Reveal Storage in Finder") {
                    Task {
                        let folder = await StorageService.shared.currentStorageFolder
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: folder.path)
                    }
                }
            }
        }

        MenuBarExtra {
            MenuBarView()
                .environment(boardViewModel)
        } label: {
            HStack(spacing: 2) {
                Image(systemName: "rectangle.split.3x1")
                if boardViewModel.menuBarBadgeCount > 0 {
                    Text("\(boardViewModel.menuBarBadgeCount)")
                }
            }
        }
        .menuBarExtraStyle(.window)
    }

    private func importBoard() {
        let panel = NSOpenPanel()
        panel.title = "Import Board"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        Task {
            await boardViewModel.importBoard(from: url)
        }
    }

    private func exportBoard() {
        let panel = NSSavePanel()
        panel.title = "Export Board"
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "board.json"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        Task {
            await boardViewModel.exportBoard(to: url)
        }
    }

    private func changeStorageFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Storage Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        Task {
            await boardViewModel.changeStorageFolder(to: url)
            await notesViewModel.reloadFromStorage()
        }
    }

    private func openAboutWindow() {
        let aboutView = AboutView()
            .preferredColorScheme(.dark)

        let hostingController = NSHostingController(rootView: aboutView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "About Propel"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
}

// MARK: - App Delegate for Global Hotkey

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var boardViewModel: BoardViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Ctrl+Shift+N: Quick capture
            if event.modifierFlags.contains([.control, .shift]), event.keyCode == 45 { // N key
                Task { @MainActor in
                    self?.quickCapture()
                }
            }
        }
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.control, .shift]), event.keyCode == 45 {
                Task { @MainActor in
                    self?.quickCapture()
                }
                return nil
            }
            return event
        }
    }

    private func quickCapture() {
        guard let vm = boardViewModel else { return }
        NSApp.activate(ignoringOtherApps: true)
        if let backlog = vm.column(for: .backlog) {
            vm.startCreatingCard(inColumn: backlog.id)
        }
    }
}
