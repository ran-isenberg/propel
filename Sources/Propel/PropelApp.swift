import SwiftUI
import UserNotifications

@main
struct PropelApp: App {
    @State private var boardViewModel = BoardViewModel()
    @State private var notesViewModel = NotesViewModel()
    @State private var showLabelManagement = false
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(boardViewModel)
                .environment(notesViewModel)
                .preferredColorScheme(.dark)
                .frame(minWidth: 800, minHeight: 500)
                .sheet(isPresented: $showLabelManagement) {
                    LabelManagementView()
                        .environment(boardViewModel)
                }
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

                Button("Manage Labels...") {
                    showLabelManagement = true
                }

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

    private func changeStorageFolder() {
        let panel = NSOpenPanel()
        panel.title = "Grant Storage Access"
        panel.message = "Propel needs permission to read and write data in the folder you select. Choose a folder for your board and notes storage."
        panel.prompt = "Grant Access"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        Task {
            await boardViewModel.changeStorageFolder(to: url)
            await notesViewModel.reloadFromStorage()
        }
    }

    @State private var aboutWindow: NSWindow?

    private func openAboutWindow() {
        if let existing = aboutWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        aboutWindow = nil

        let aboutView = AboutView()
            .preferredColorScheme(.dark)

        let hostingController = NSHostingController(rootView: aboutView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "About Propel"
        window.styleMask = [.titled, .closable]
        window.center()
        window.makeKeyAndOrderFront(nil)
        aboutWindow = window
    }
}

// MARK: - App Delegate for Global Hotkey

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var boardViewModel: BoardViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self

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

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    private func quickCapture() {
        guard let vm = boardViewModel else { return }
        NSApp.activate(ignoringOtherApps: true)
        if let backlog = vm.column(for: .backlog) {
            vm.startCreatingCard(inColumn: backlog.id)
        }
    }
}
