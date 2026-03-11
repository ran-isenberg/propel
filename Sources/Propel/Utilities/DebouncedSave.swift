import Foundation

@MainActor
final class DebouncedSave {
    private var task: Task<Void, Never>?
    private let delay: Duration
    private let action: @MainActor () async -> Void

    init(delay: Duration = .seconds(1), action: @escaping @MainActor () async -> Void) {
        self.delay = delay
        self.action = action
    }

    func schedule() {
        task?.cancel()
        task = Task { @MainActor in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await action()
        }
    }

    func saveNow() {
        task?.cancel()
        task = Task { @MainActor in
            await action()
        }
    }
}
